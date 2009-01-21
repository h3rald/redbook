#!/usr/bin/env ruby

module RedBook
	class Repository

		include Hookable
		
		def self.setup(params)
			DataMapper.setup(:default, params)
		end

		@resources = []
		class << self; attr_accessor :resources; end

		def self.reset
			self.resources.each { |r| r.auto_migrate! }
		end

		class Entry
			include DataMapper::Resource

			storage_names[:default] = 'entries'

			property :id, Serial
			property :text, String, :nullable => false
			property :type, String, :nullable => false, :default => 'entry'
			property :timestamp, DateTime, :nullable => false

		end

		resources << Entry

	end
end
