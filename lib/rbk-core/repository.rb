#!/usr/bin/env ruby

module RedBook
	class Repository

		include Hookable
		
		def self.setup(params)
			self.hook :before_setup, :params => params
			DataMapper.setup(:default, params)
			self.hook :after_setup
		end

		def self.reset
			self.hook :before_reset
			Entry.auto_migrate!
			self.hook :after_reset
		end

		class Entry
			include DataMapper::Resource

			storage_names[:default] = 'entries'

			property :id, Serial
			property :text, String, :nullable => false
			property :type, String, :nullable => false, :default => 'entry'
			property :timestamp, DateTime, :nullable => false

		end

	end
end
