#!/usr/bin/env ruby

module RedBook

	inventory_tables << :versions
	inventory_tables << :projects

	class TrackingPlugin < Plugin


		class << self; attr_accessor :add_resources; end

		def setup
			create_table :activities
			create_table :projects
			create_table :versions
		end


	end

	class Repository

		class Activity
			include DataMapper::Resource
			belongs_to :entry 
			belongs_to :version
			belongs_to :project
			has n, :tracking
			property :entry_id, Integer, :key => true
			property :ref, String
			property :completion, Time
			property :duration, Float
			property :tracking, Boolean
			storage_names[:default] = 'activities'

			alias set_duration duration 

			def duration
				# Duration attribute overrides effective duration
				return set_duration if set_duration
			end

			def paused?
				started? ? false : true 
			end

			def completed?
				!completion.blank?
			end

			def started?
				self.tracking.first(:end => nil) 
			end

		end

		class Tracking
			include DataMapper::Resource
			storage_names[:default] = 'tracking'
			belongs_to :activity
			property :start, Time
			property :end, Time
		end

		class Entry
			has 1, :activity
		end

		class Project
			include DataMapper::Resource
			has n, :entries
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

	class Parser

		operations[:log].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:track) { |p| p.type = :bool }
			o.parameter(:completion) { |p| p.type = :time } 
			o.parameter(:duration) { |p| p.type = :integer }
		end

		operations[:select].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:track) { |p| p.type = :bool }
			o.parameter(:longerthan) { |p| p.type = :time } 
			o.parameter(:shorterthan) { |p| p.type = :time } 
			o.parameter(:before) { |p| p.type = :time } 
			o.parameter(:after) { |p| p.type = :time } 
			o.post_parsing << lambda do |params| 
				result = {}
				result['activity.duration.lt'] = params[:shorterthan] unless params[:shorterthan].blank?
				result['activity.duration.gt'] = params[:longerthan] unless params[:longerthan].blank?
				result['activity.completion.lt'] = params[:before] unless params[:before].blank?
				result['activity.completion.gt'] = params[:after] unless params[:after].blank?
				result['activity.project.name'] = params[:project] unless params[:project].blank? 
				result['activity.version.name'] = params[:version] unless params[:version].blank? 
				result['activity.ref'] = params[:ref] unless params[:ref].blank? 
				params.delete(:shorterthan)
				params.delete(:longerthan)
				params.delete(:before)
				params.delete(:after)
				params.merge! result
			end
		end

		operations[:update].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:track) { |p| p.type = :bool }
			o.parameter(:completion) { |p| p.type = :time } 
			o.parameter(:duration) { |p| p.type = :integer }
		end

		# New Operations

		operation(:start) do |o|
			o.parameter(:start) { |p| p.type = :intlist}
		end

		operation(:finish) do |o|
			o.parameter(:finish) { |p| p.type = :intlist}
		end

		operation(:pause) do |o|
			o.parameter(:pause) { |p| p.type = :intlist}
		end

		special_attributes << :project
		special_attributes << :version
		special_attributes << :ref
		special_attributes << :completion
		special_attributes << :duration

	end

	class Engine


		def start(indexes=nil)
			raise EngineError, "Empty dataset" if @dataset.blank?
			# Start tracking all activities
			if indexes.blank?	
				@dataset.each do |e|
					Repository::Tracking.create(:activity_id => e.activity_id, :start => Time.now) unless e.activity.started?
				end
			else
				indexes.each do |i|
					entry = @dataset[i-1]
					unless entry
						warning "Invalid index #{i}"
						next
					end
					if entry.activity.started?
						warning "Activity ##{i} already started"
						next
					end
					Repository::Tracking.create(:activity_id => entry.activity_id, :start => Time.now) 
				end
			end
		end
		

		define_hook(:after_update) do |params|
			project = params[:attributes][:project]
			version = params[:attributes][:version]
			ref = params[:attributes][:ref]
			track = params[:attributes][:track]
			completion = params[:attributes][:completion]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if track || project || version || ref || completion || duration then	
				activity =  Repository::Activity.first(:entry_id => entry.id) || Repository::Activity.create(:entry_id => entry.id)  
				activity.project = entry.resource :project, project unless project.blank?
				activity.version = entry.resource :version, version unless version.blank?
				activity.ref = ref
				activity.track = track
				activity.completion = completion
				activity.duration = duration
				activity.save
			end
		end

		define_hook(:after_insert) do |params|
			project = params[:attributes][:project]
			version = params[:attributes][:version]
			ref = params[:attributes][:ref]
			track = params[:attributes][:track]
			completion = params[:attributes][:completion]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if track || project || version || ref || completion || duration then	
				activity =  Repository::Activity.create(:entry_id => entry.id)	
				activity.project = entry.resource :project, project unless project.blank?
				activity.version = entry.resource :version, version unless version.blank?
				activity.ref = ref
				activity.track = track
				activity.completion = completion
				activity.duration = duration
				activity.save
			end
		end


	end

end
