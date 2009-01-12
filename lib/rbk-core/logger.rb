#!/usr/bin/env ruby

module RedBook

	class Logger

		def initialize(config=nil)
			raise ArgumentError, "No configuration file specified" unless config
			@config = config
			db = "#{RedBook::HOME_DIR}/log.rbk"
			@repository = @config[:repository] | "sqlite3://#{db}"
			RedBook::Repository.setup @repository
			create_repository unless File.exists? db			
		end
		
		private

		def create_repository
			RedBook::Repository.reset
		end

	end
end
