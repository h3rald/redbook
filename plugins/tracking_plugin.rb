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
			has n, :records
			property :entry_id, Integer, :key => true
			property :ref, String
			property :completion, Time
			property :duration, Float
			property :tracking, String
			storage_names[:default] = 'activities'

			def track
				return if tracking == 'disabled'
				records = Repository::Record.all(:activity_id => id)
				duration = 0
				records.each { |r| duration+= r.duration }
			end

			def paused?
				tracking == 'paused' 
			end

			def completed?
				tracking == 'completed'
			end

			def started?
				tracking == 'started'
			end

			def disabled?
				tracking == 'disabled'
			end

		end

		class Record
			include DataMapper::Resource
			storage_names[:default] = 'records'
			belongs_to :activity
			property :start, Time, :nullable => false
			property :end, Time

			def duration
				end_time = self.end || Time.now
				(end_time - self.start)*3600
			end

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
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:completion) { |p| p.type = :time } 
			o.parameter(:duration) { |p| p.type = :float }
		end

		operations[:select].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:before) { |p| p.type = :time } 
			o.parameter(:after) { |p| p.type = :time } 
			o.parameter(:longerthan) { |p| p.type = :float }
			o.parameter(:shorterthan) { |p| p.type = :float }
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
				params.delete(:project)
				params.delete(:version)
				params.delete(:ref)
				params.merge! result
			end
		end

		operations[:update].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:track) { |p| p.type = :bool }
			o.parameter(:completion) { |p| p.type = :time } 
			o.parameter(:duration) { |p| p.type = :float }
		end

		# New Operations

		operation(:start) do |o|
			o.parameter(:start) { |p| p.type = :integer; p.required = true}
		end

		operation(:finish) do |o|
			o.parameter(:finish) { |p| p.type = :integer}
		end

		operation(:pause) do |o|
			o.parameter(:pause) { |p| p.type = :integer; p.required = true}
		end

		operation(:track) do |o|
			o.parameter(:track) { |p| p.type => :integer; p.required = true}
			o.parameter(:from) { |p| p.type => :time; p.required = true}
			o.parameter(:to) { |p| p.type => :time; p.required = true}
		end

		operation(:untrack) do |o|
			o.parameter(:track) { |p| p.type => :integer; p.required = true}
			o.parameter(:from) { |p| p.type => :time}
			o.parameter(:to) { |p| p.type => :time}
		end

		special_attributes << :project
		special_attributes << :version
		special_attributes << :ref
		special_attributes << :completion
		special_attributes << :duration

	end

	class Engine


		def start(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[i-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity, break or process" unless ['activity', 'break', 'process'].include? entry.type
			raise EngineError, "Tracking is disabled for selected #{entry.type.to_s}." if entry.activity.disabled?
			raise EngineError, "Selected #{entry.type.to_s} is already started." if entry.activity.started?
			Repository::Tracking.create(:activity_id => entry.activity_id, :start => Time.now) 
		end

		def finish(index=nil)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[i-1] if index
			raise EngineError, "Invalid index #{i}" unless entry
			# if no index specified, get the first (and only) started activity or break.
			entry = Repositor::Entry.first('activity.tracking' => 'started', :type => ['activity', 'break']) 
			raise EngineError, "No activity/break started." unless entry
			raise EngineError, "Selected entry is not an activity, break or process" unless ['activity', 'break', 'process'].include? entry.type
			raise EngineError, "Tracking is disabled for selected #{entry.type.to_s}." if entry.activity.disabled?
			raise EngineError, "Selected #{entry.type.to_s} is already #{entry.activity.tracking}." unless entry.activity.started?
			# Verify if there's any open record
			open = Repository::Record.first(:activity_id => entry.activity_id, :end => nil)
			if open then
				open.end = Time.now
				open.save
			end
			entry.activity.track
			entry.activity.completion = Time.now
			entry.activity.save
		end

		def pause(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[i-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity, break or process" unless ['activity', 'break', 'process'].include? entry.type
			raise EngineError, "Tracking is disabled for selected #{entry.type.to_s}." if entry.activity.disabled?
			raise EngineError, "Selected #{entry.type.to_s} is already #{entry.activity.tracking}." unless entry.activity.started?
			open = Repository::Record.first(:activity_id => entry.activity_id, :end => nil)
			open.end = Time.now
			open.save
			entry.activity.track
			entry.activity.save
		end

		def track(index, from, to)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[i-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity, break or process" unless ['activity', 'break', 'process'].include? entry.type
			raise EngineError, "Tracking is disabled for selected #{entry.type.to_s}." if entry.activity.disabled?
			started = Repository::Record.all(:activity_id => entry.activity_id, :start.gt => from)
			ended = Repository::Record.all(:activity_id => entry.activity_id, :end.lt => to)
			raise EngineError, "Operation not allowed (overlapping records)." unless started.blank? && ended.blank?
			Repository::Record.create :activity_id => entry.activity_id, :start => from, :end => to
		end

		def untrack
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[i-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity, break or process" unless ['activity', 'break', 'process'].include? entry.type
			raise EngineError, "Tracking is disabled for selected #{entry.type.to_s}." if entry.activity.disabled?
			records = Repository::Record.all(:activity_id => entry.activity_id, :start.gt => from, :end.lt => to)
			raise EngineError, "No tracking records in the specified interval." records.blank?
			records.each { |r| r.destroy }
		end

		define_hook(:after_update) do |params|
			project = params[:attributes][:project]
			version = params[:attributes][:version]
			ref = params[:attributes][:ref]
			track = params[:attributes][:tracking]
			completion = params[:attributes][:completion]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if tracking || project || version || ref || completion || duration then	
				activity =  Repository::Activity.first(:entry_id => entry.id) || Repository::Activity.create(:entry_id => entry.id)  
				activity.project = entry.resource :project, project unless project.blank?
				activity.version = entry.resource :version, version unless version.blank?
				activity.ref = ref
				activity.tracking = tracking
				activity.completion = completion
				activity.duration = duration
				activity.save
			end
		end

		define_hook(:after_insert) do |params|
			project = params[:attributes][:project]
			version = params[:attributes][:version]
			ref = params[:attributes][:ref]
			track = params[:attributes][:tracking]
			completion = params[:attributes][:completion]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if tracking || project || version || ref || completion || duration then	
				activity =  Repository::Activity.create(:entry_id => entry.id)	
				activity.project = entry.resource :project, project unless project.blank?
				activity.version = entry.resource :version, version unless version.blank?
				activity.ref = ref
				activity.tracking = tracking
				activity.completion = completion
				activity.duration = duration
				activity.save
			end
		end


	end

end
