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

		attr_accessor :repository, :dataset
		
		# Sets up the repository. 
		# If +db+ is not specified, a new SQLite database is created in
		# <tt>$HOME/log.rbk</tt> (*nix, Mac) or <tt>%HOMEPATH%/log.rbk</tt>
		# (Windows).
		#
		# <i>Hooks</i>
		# * <i>:before_initialize</i> :db => String
		# * <i>:after_initialize</i> :repository => String, :dataset => Array 
		def initialize(db=nil)
			hook :before_initialize, :db => db
			db ||= "#{RedBook::HOME_DIR}/log.rbk"
			@repository = "sqlite3://#{db}"
			@dataset = []
			Repository.setup @repository
			create_repository unless File.exists? db
			hook :after_initialize, :repository => @repository, :dataset => @dataset		
		end

		# Logs an entry to the repository. 
		#
		# <i>Hooks</i>
		# * <i>:before_insert</i> :attributes => Hash
		# * <i>:after_insert</i> :attributes => Hash
		def log(attributes={})
			hook :before_insert, :attributes => attributes
			insert_entry attributes
			hook :after_insert, :attributes => attributes
		end
		
		# Selects entries matching specified criteria.
		#
		# <i>Hooks</i>
		# * <i>:before_select</i> :attributes => Hash
		# * <i>:after_select</i> :attributes => Hash
		def select(attributes={})
			hook :before_select, :attributes => attributes
			@dataset = select_entries attributes
			hook :after_select, :attributes => attributes
			@dataset
		end

		# Updates an entry loaded into the dataset.
		#
		# <i>Hooks</i>
		# * <i>:before_update</i> :index => Integer, :attributes => Hash
		# * <i>:after_update</i> :index => Integer, :attributes => Hash
		def update(index, attributes={})
			hook :before_update, :index => index, :attributes => attributes
			entry = update_entry index, attributes
			hook :after_update, :index => index, :attributes => attributes
			entry
		end

		# Deletes an entry loaded into the dataset.
		#
		# <i>Hooks</i>
		# * <i>:before_delete</i> :index => Integer
		# * <i>:after_delete</i> :index => Integer
		def delete(index)
			hook :before_delete, :index => index
			delete_entry index
			hook :after_delete, :index => index
		end

		# Saves the dataset's contents to a file
		#
		# <i>Hooks</i>
		# * <i>:before_save</i> :file => String, :format => Symbol
		# * <i>:after_save</i> :file => String
		def save(file, format=:txt)
			raise EngineError, "Empty dataset." if @dataset.blank?
			em = Emitter.new(format)
			em.load_template :entry
			hook :before_save, :file => file, :format => format
			File.open(file, 'w+')	do |f|
				@dataset.each do |entry|
					f.write em.render(:entry, :entry => entry)
				end
			end
			hook :after_save, :file => file
		end

		private

		def create_repository
			Repository.reset
		end

		def insert_entry(attributes={})
			entry = Repository::Entry.new attributes
			raise Exception, "Entry text not specified" unless attributes[:text] 
			entry.type = "entry"
			entry.timestamp = Time.now unless attributes[:timestamp]
			entry.save
		end

		def update_entry(index, attributes={})
			raise EngineError, "Empty index" if @dataset.blank?
			raise EngineError, "Invalid dataset index" unless index >=0 && index < @dataset.length
			raise EngineError, "Nothing to update" if attributes.blank?
			entry = @dataset[index]
			entry.attributes = attributes
			entry.save
		end
		
		def delete_entry(index)
			raise EngineError, "Empty index" if @dataset.blank?
			raise EngineError, "Invalid dataset index" unless index >=0 && index < @dataset.length
			entry = @dataset[index]
			entry.destroy
		end

		def select_entries(attributes={})
			Repository::Entry.all(attributes)
		end

	end
end
