#!/usr/bin/env ruby

module RedBook

	# The main RedBook class, used to access the repository.
	#
	# <i>Usage</i>
	#
	#	e = RedBook::Engine.new
	#	e.log :text => "an entry"
	#	e.log :text => "another entry"
	#	e.log :text => "yet another entry"
	#	e.select :text.like => "%another%" # Loads entry 2 and 3 into dataset
	#	e.update 2, :text => "An updated entry"
	#	e.delete 3
	class Engine

		include Hookable
		include Messaging

		attr_accessor :repository, :dataset, :db, :special_attributes, :inventory

		# Sets up the repository. 
		# If +db+ is not specified, a new SQLite database is created in
		# <tt>$HOME/repository.rbk</tt> (*nix, Mac) or <tt>C:/repository.rbk</tt>
		# (Windows).
		#
		# <i>Hooks</i>
		# * <i>:before_initialize</i> :db => String
		# * <i>:after_initialize</i> :repository => String, :dataset => Array 
		def initialize(db=nil)
			hook :before_initialize, :db => db
			@db = db || RedBook.config.repositories[:default] 
			@repository = "sqlite3://#{@db}"
			@dataset = []
			@inventory = {}
			Repository.setup @repository
			create_repository unless File.exists? @db
			hook :after_initialize, :repository => @repository, :dataset => @dataset		
		end

		# Logs an entry to the repository. 
		#
		# <i>Hooks</i>
		# * <i>:before_insert</i> :attributes => Hash
		# * <i>:after_insert</i> :attributes => Hash, :entry => RedBook::Repository::Entry
		def log(attributes={})
			hook :before_insert, :attributes => attributes
			entry = insert_entry attributes
			hook :after_insert, :attributes => attributes, :entry => entry
			entry
		end

		alias insert log

		# Selects entries matching specified criteria.
		#
		# <i>Hooks</i>
		# * <i>:before_select</i> :attributes => Hash
		# * <i>:after_select</i> :attributes => Hash, :dataset => Array
		def select(attributes=nil)
			attributes = {} if attributes.blank?
			hook :before_select, :attributes => attributes
			@dataset = select_entries attributes
			hook :after_select, :attributes => attributes, :dataset => @dataset
			filter_dataset attributes
			@dataset
		end

		# Updates an entry loaded into the dataset.
		# (index is 1-based).
		#
		# <i>Hooks</i>
		# * <i>:before_update</i> :index => Integer, :attributes => Hash
		# * <i>:after_update</i> :entry => RedBook::Repository::Entry
		def update(index, attributes={})
			hook :before_update, :index => index, :attributes => attributes
			entry = update_entry index-1, attributes
			hook :after_update, :attributes => attributes, :entry => entry
			entry
		end

		# Deletes one or more entries loaded into the dataset. 
		# Indexes is an array of dataset indexes (1-based).
		#
		# <i>Hooks</i>
		# * <i>:before_delete</i> :indexes => Integer
		# * <i>:before_each_delete</i> :entry => RedBook::Repository::Entry
		# * <i>:after_each_delete</i> :entry => RedBook::Repository::Entry
		# * <i>:after_delete</i>
		def delete(indexes=nil)
			hook :before_delete, :indexes => indexes
			raise EngineError, "Empty dataset." if @dataset.blank?
			if indexes.blank?
				# Deletes the whole dataset
				@dataset.each do |e| 
					hook :before_each_delete, :entry => e
					delete_entry e
					hook :after_each_delete, :entry => e
				end
			else
				indexes.each do |i| 
					entry = @dataset[i-1]
					unless entry
						warning "Invalid index #{i}."
						next
					end
					hook :before_each_delete, :entry => entry
					delete_entry entry
					hook :after_each_delete, :entry => entry
				end
			end
			hook :after_delete
		end

		# Saves the dataset's contents to a file
		#
		# <i>Hooks</i>
		# * <i>:before_save</i> :file => String, :format => Symbol
		# * <i>:after_save</i> :file => String
		def save(file, format=:txt)
			raise EngineError, "Empty dataset." if @dataset.blank?
			em = Emitter.new(format)
			hook :before_save, :file => file, :format => format
			File.open(file, 'w+')	do |f|
				f.write em.render @dataset
			end
			hook :after_save, :file => file
		end

		# Renames any record which has a name field
		def rename(type, from, to)
			c = RedBook::Repository.const_get "#{type.to_s.camel_case}".to_sym
			raise EngineError, "Unknown table '#{type.to_s.plural}'." unless c
			raise EngineError, "#{type.to_s.camel_case.plural} cannot be renamed." unless c.method_defined? :name
			c.first(:name => from).tap do |i|
				raise EngineError, "There is no #{type.to_s} called '#{from}'" unless i
				i.name = to
				i.save
			end
		end

		# Redefining Messaging::debug
		alias m_debug debug

		# Toggles debug output.
		def debug
			RedBook.debug = !RedBook.debug
		end

		# Toggles standard output.
		def output
			RedBook.output = !RedBook.output
		end

		# Retrieves and saves the name of all the records of a given table.
		# (currently used for completion purposes only).
		#
		# <i>Hooks</i>
		# * <i>:before_refresh</i> :tables => Array [Symbol] 
		# * <i>:after_refresh</i> :inventory => Array [Hash][Object] 
		# * <i>:before_refresh_table</i> :table => Symbol 
		# * <i>:after_refresh_table</i> :tables => Hash [Object] 
		def refresh(tables=[])
			hook :before_refresh, :tables => tables
			tables.then(:blank?){RedBook.inventory_tables}.else{tables}.each do |t|
				hook :before_refresh_table, :table => t.to_s
				model = Repository.const_get(:"#{t.to_s.camel_case.singular}")
				raise EngineError, "Table '#{t.to_s}' not found." unless model
				raise EngineError, "#{t.to_s.camel_case} cannot be added to the inventory." unless model.method_defined? :name
				@inventory[t.to_sym] = []
				model.all.each do |i|
					@inventory[t.to_sym] << i.name
				end
				hook :after_refresh_table, :inventory_table => @inventory[t.to_sym]
			end
			hook :after_refresh, :inventory => @inventory
		end

		# Evaluates a string as Ruby code.
		def ruby(string)
			begin
				Kernel.instance_eval string
			rescue
				raise EngineError, "Error evaluating '#{string}'"
			end
		end	

		# Cleans up unused auxiliary records belonging to specific tables.
		def cleanup(tables=[])
			target = tables.then(:blank?){RedBook.inventory_tables}.else{tables}.each{ |t| cleanup_table t }
		end

		# Private methods

		private

		def filter_dataset(attributes)
			i = 0
			while i < @dataset.length
				@dataset[i] = nil unless hook :filter_dataset, :entry => @dataset[i], :attributes => attributes
				i = i+1
			end
			@dataset.compact!
		end

		def cleanup_table(table)
			begin
				name = table.to_s.singularize
				model = name.camel_case.to_sym
				Repository.const_get(model).all.each do |o|
					Repository.const_get("#{model.to_s}Map".to_sym).first("#{name}_id".to_sym => o.id).then(:blank?) do
						o.destroy
					end
				end
			rescue
				raise EngineError, "Unable to cleanup '#{table.to_s}'"
			end
		end

		def create_repository
			Repository.reset
		end

		def valid_index?(index)
			index >=0 && index < @dataset.length
		end

		def get_selected_entries(indexes=nil)
			entries = []
			if indexes.blank?
				entries = @dataset
			else
				# Indexes are 1-based
				indexes.each do |i|
					entry = @dataset[i-1]
					if entry.blank?
						warning "Invalid index #{i}."
					else
						entries << entry
					end
				end
			end
			entries
		end

		def insert_entry(attributes={})
			# Delete special attributes
			attributes[:resource_type] = attributes[:type] if attributes[:type]
			attributes.delete :type
			attrs = attributes.dup
			attrs.each_pair do |l, v|
				param = RedBook.operations[:log].parameters[l]
				attrs.delete l if param.chain [:set?, :special]
			end
			Repository::Entry.new(attrs).tap do |entry|
				raise Exception, "Entry text not specified" unless attrs[:text] 
				entry.resource_type = "entry" unless attrs[:resource_type]
				entry.timestamp = Time.now unless attrs[:timestamp]
				entry.save
			end
		end

		def update_entry(index, attributes={})
			# Delete special attributes
			attributes[:resource_type] = attributes[:type] if attributes[:type]
			attributes.delete :type
			attrs = attributes.dup
			attrs.each_pair do |l, v|
				param = RedBook.operations[:update].parameters[l]
				attrs.delete l if param.chain [:set?, :special]
			end
			raise EngineError, "Empty dataset" if @dataset.blank?
			raise EngineError, "Invalid dataset index" unless valid_index? index
			raise EngineError, "Nothing to update" if attributes.blank? # Must check *all* attributes
			@dataset[index].tap do |entry|
				attrs.else(:blank?).then do
					entry.attributes = attrs
					entry.save
				end
			end
		end

		def delete_entry(entry)
			entry.destroy
			entry
		end

		def select_entries(attributes={})
			attributes[:resource_type] = attributes[:type] if attributes[:type]
			attributes.delete :type
			attrs = attributes.dup
			limit, type = attrs.delete(:first), :first if attrs[:first]
			limit, type = attrs.delete(:last), :last if attrs[:last]
			# Delete unknown attributes
			attrs.each_pair do |l, v|
				param = RedBook.operations[:select].parameters[l]
				attrs.delete l if param.chain [:set?, :special]
			end
			type ||= :select	
			case type
			when :select then
				Repository::Entry.all(attrs)
			when :first then
				Repository::Entry.first(limit, attrs)
			when :last then
				attrs[:order] = [:timestamp.desc]
				Repository::Entry.first(limit, attrs)
			end
		end

	end
end
