#!/usr/bin/env ruby

module RedBook
	module Repository

		def self.setup(params)
			DataMapper.setup(:default, params)
		end

		def self.reset
			Entry.auto_migrate!
		end

		class Entry
			include DataMapper::Resource

			property :id, Serial
			property :text, String, :nullable => false
			property :type, String, :nullable => false, :default => 'entry'
			property :timestamp, DateTime, :nullable => false

		end

	end
end
