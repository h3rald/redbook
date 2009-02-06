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

			default_scope(:default).update(:order => [:timestamp.asc]) # set default order
		
			def resource(type, name)
				klass = Repository.const_get(type.to_s.camelize.to_sym)
				item = klass.first(:name => name) || klass.create(:name => name)
				item
			end

		end


		resources << Entry

	end
end
