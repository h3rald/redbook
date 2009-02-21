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
			@db = db || RedBook.config.repositories.default 
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

		# Relogs a previouly logged entry.
		#
		# <i>Hooks</i>
		# * <i>:before_relog</i> :attributes => Hash, :entry => RedBook::Repository::Entry
		# * <i>:after_relog</i> :attributes => Hash, :entry => RedBook::Repository::Entry
		def relog(index, type=nil)
			raise EngineError, "Empty dataset." if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{index}." unless entry
			attributes = {}
			attributes[:timestamp] = Time.now
			attributes[:text] = entry.text
			attributes[:type] = type || entry.type
			hook :before_relog, :entry => entry, :attributes => attributes
			new_entry = log(attributes)
			hook :after_relog, :attributes => attributes, :entry => new_entry
		end
		
		# Selects entries matching specified criteria.
		#
		# <i>Hooks</i>
		# * <i>:before_select</i> :attributes => Hash
		# * <i>:after_select</i> :attributes => Hash, :dataset => Array
		def select(attributes=nil)
			attributes = {} if attributes.blank?
			hook :before_select, :attributes => attributes
			m_debug ":select attributes:" 
			m_debug attributes.to_yaml
			@dataset = select_entries attributes
			hook :after_select, :attributes => attributes, :dataset => @dataset
			m_debug "Items in dataset: #{@dataset.length.to_s}"
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
		# * <i>:saved_file_header</i> :format => Symbol # => String
		# * <i>:saved_file_footer</i> :format => Symbol # => String
		def save(file, format=:txt)
			raise EngineError, "Empty dataset." if @dataset.blank?
			em = Emitter.new(format)
			em.load_template :entry
			hook :before_save, :file => file, :format => format
			File.open(file, 'w+')	do |f|
				header = hook :saved_file_header, :format => format
				f.write header unless header.blank?
				@dataset.each do |entry|
					f.write em.render(entry.type.to_sym, :entry => entry)
				end
				footer = hook :saved_file_footer , :format => format
				f.write footer unless footer.blank?
			end
			hook :after_save, :file => file
		end

		# Renames any record which has a name field
		def rename(type, from, to)
			c = RedBook::Repository.const_get "#{type.to_s.camelize}".to_sym
			raise EngineError, "Unknown table '#{type.to_s.plural}'." unless c
			raise EngineError, "#{type.to_s.camelize.plural} cannot be renamed." unless c.method_defined? :name
			item = c.first :name => from
			raise EngineError, "There is no #{type.to_s} called '#{from}'" unless item
			item.name = to
			item.save
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
			inv_tables = (tables.blank?) ? RedBook.inventory_tables : tables
			inv_tables.each do |t|
				hook :before_refresh_table, :table => t.to_s
				model = Repository.const_get(:"#{t.to_s.camelize.singular}")
				raise EngineError, "Table '#{t.to_s}' not found." unless model
				raise EngineError, "#{t.to_s.camelize} cannot be added to the inventory." unless model.method_defined? :name
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
			hook :cleanup, :tables => tables
		end

		private

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
			attrs = attributes.dup
			attrs.each_pair do |l, v|
				param = Parser.operations[:log].parameters[l]
				attrs.delete l if param && param.special
			end
			entry = Repository::Entry.new attrs
			raise Exception, "Entry text not specified" unless attrs[:text] 
			entry.type = "entry" unless attrs[:type]
			entry.timestamp = Time.now unless attrs[:timestamp]
			entry.save
			entry
		end

		def update_entry(index, attributes={})
			# Delete special attributes
			attrs = attributes.dup
			attrs.each_pair do |l, v|
				param = Parser.operations[:update].parameters[l]
				attrs.delete l if param && param.special
			end
			raise EngineError, "Empty dataset" if @dataset.blank?
			raise EngineError, "Invalid dataset index" unless valid_index? index
			raise EngineError, "Nothing to update" if attributes.blank? # Must check *all* attributes
			entry = @dataset[index]
			unless attrs.blank? then
				entry.attributes = attrs
				entry.save
			end
			entry
		end
		
		def delete_entry(entry)
			entry.destroy
			entry
		end

		def select_entries(attributes={})
			attrs = attributes.dup
			limit, type = attrs.delete(:first), :first if attrs[:first]
			limit, type = attrs.delete(:last), :last if attrs[:last]
			# Delete unknown attributes
			attrs.each_pair do |l, v|
				param = Parser.operations[:select].parameters[l]
				attrs.delete l if param && param.special
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

# Implementing hooks for saving XML and XHTML files

RedBook::Engine.define_hook :saved_file_header do |params|
	result = ""
	case params[:format]
	when :xml then
		result <<	"<xml version=\"1.0\" encoding=\"UTF-8\">\n"
		result << "<dataset>\n"
	when :html||:xhtml then
		result << "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n"
		result << "<head>\n"
		result << "	<title>RedBook Dataset</title>\n"
		result << "</head>\n"
		result << "<body>\n"
		result << "<h1>RedBook Dataset</h1>\n"
		result << "<div id=\"dataset\">\n"
	end
	{ :value => result, :stop => result ? true : false }
end

RedBook::Engine.define_hook :saved_file_footer do |params|
	result = ""
	case params[:format]
	when :xml then
		result << "\n</dataset>\n"
	when :html||:xhtml then
		result << "\n</div>\n"
		result << "</body>\n"
	end
	{ :value => result, :stop => result ? true : false }
end

		
		
	
