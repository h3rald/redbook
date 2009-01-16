#!/usr/bin/env ruby

module RedBook

	class Engine
		
		include Messaging
		include Hookable

		attr_accessor :repository, :dataset
		
		def initialize(db=nil)
			db ||= "#{RedBook::HOME_DIR}/log.rbk"
			@repository = "sqlite3://#{db}"
			Repository.setup @repository
			create_repository unless File.exists? db			
		end

		def log(params={})
			hook :before_insert_entry, params
			insert_entry params
			hook :after_insert_entry, params
		end

		def select(params={})
			hook :before_select_entries, params
			@dataset = select_entries params
			hook :after_select_entries, params
			@dataset
		end
		
		private

		def create_repository
			Repository.reset
		end

		def insert_entry(params={})
			entry = Repository::Entry.new params
			raise Exception, "Entry text not specified" unless params[:text] 
			entry.type = "entry"
			entry.timestamp = Time.now unless params[:timestamp]
			entry.save
		end

		def select_entries(params={})
			Repository::Entry.all(params)
		end

	end
end
