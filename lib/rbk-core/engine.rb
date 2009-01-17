#!/usr/bin/env ruby

module RedBook

	class Engine
		
		include Messaging
		include Hookable

		attr_accessor :repository, :dataset
		
		def initialize(db=nil)
			db ||= "#{RedBook::HOME_DIR}/log.rbk"
			@repository = "sqlite3://#{db}"
			@dataset = []
			Repository.setup @repository
			create_repository unless File.exists? db			
		end

		def log(attributes={})
			hook :before_insert, :attributes => attributes
			insert_entry attributes
			hook :after_insert, :attributes => attributes
		end

		def select(attributes={})
			hook :before_select, :attributes => attributes
			@dataset = select_entries attributes
			hook :after_select, :attributes => attributes
			@dataset
		end

		def update(index, attributes={})
			hook :before_update, :index => index, :attributes => attributes
			entry = update_entry index, attributes
			hook :after_update, :index => index, :attributes => attributes
			entry
		end

		def delete(index)
			hook :before_delete, :index => index
			delete_entry index
			hook :after_delete, :index => index
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
