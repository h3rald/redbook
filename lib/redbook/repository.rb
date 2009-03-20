#!/usr/bin/env ruby

module RedBook
	class Repository

		include Hookable
		
		def self.setup(params)
			DataMapper.setup(:default, params)
		end

		def self.query(string)
			DataMapper.repository(:default).adapter.query(string)
		end

		class_instance_variable :resources => []

		def self.reset
			self.resources.each { |r| r.auto_migrate! }
		end

		class Entry
			include DataMapper::Resource

			storage_names[:default] = 'entries'

			property :id, Serial
			property :text, String, :nullable => false
			property :resource_type, String, :nullable => false, :default => 'entry'
			property :timestamp, DateTime, :nullable => false

			default_scope(:default).update(:order => [:timestamp.asc]) # set default order
		
			def resource(type, name)
				return nil if name == nil
				klass = Repository.const_get(type.to_s.camelize.to_sym)
				item = klass.first(:name => name) || klass.create(:name => name)
				item
			end

		end

		resources << Entry

	end
end
