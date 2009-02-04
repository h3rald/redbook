#!/usr/bin/env ruby

module RedBook

	class TrackingPlugin < Plugin

		def setup
			create_table :activities
			create_table :projects
			create_table :versions
		end
	end

	class Repository

		class Activity
			include DataMapper::Resource
			has 1, :entry 
			has 1, :version
			has 1, :project
			property :entry_id, Integer, :key => true, :nullable => false, :unique => true
			property :project_id, Integer, :key => true
			property :version_id, Integer, :key => true
			property :ref, String
			property :completion, Time
			property :duration, Float
			storage_names[:default] = 'activities'
		end

		class Entry
			has 1, :activity
		end

		class Project
			include DataMapper::Resource
			has n, :activities
			property :id, Serial
			property :name, String, :unique => true, :nullable => false
			storage_names[:default] = 'projects'
		end

		class Version
			include DataMapper::Resource
			has n, :activities
			property :id, Serial
			property :name, String, :unique => true, :nullable => false
			storage_names[:default] = 'versions'
		end

		resources << Project
		resources << Version
		resources << Activity

	end




end
