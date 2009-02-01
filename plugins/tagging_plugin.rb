#!/usr/bin/env ruby

module RedBook
	class Repository 

		class Tag
			include DataMapper::Resource
			has n, :entries, :through => Resource, :class_name => 'RedBook::Repository::Entry'
			property :name, String, :key => true

			storage_names[:default] = 'tags'
		end

		class Entry
			has n, :tags, :through => Resource, :class_name => 'RedBook::Repository::Tag'
		end

	end


	### Plugin Class

	class TaggingPlugin < Plugin

		def setup_actions
			begin
				Repository::Tag.first
			rescue
				Repository::Tag.auto_migrate!
				debug " -> Created tags table."
			end
		end

	end
end



