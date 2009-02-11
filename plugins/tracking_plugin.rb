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
			create_table :records
		end
	end

	class Cli

		def start_operation(params)
			entry = @engine.start params[:start]
			info "Activity started."
		end

		def finish_operation(params)
			entry = @engine.finish params[:finish]
			info "Activity stopped."
		end

		def pause_operation(params)
			entry = @engine.pause params[:pause]
			info "Activity paused."
		end

	end

	class Repository

		class Activity
			include DataMapper::Resource
			belongs_to :entry 
			belongs_to :version
			belongs_to :project
			property :entry_id, Integer, :key => true
			property :foreground, Boolean
			property :ref, String
			property :completion, Time
			property :duration, Float
			property :tracking, String
			storage_names[:default] = 'activities'

			def track
				return if tracking == 'disabled'
				records = Repository::Record.all(:entry_id => entry_id)
				self.duration = 0
				records.each { |r| self.duration+= r.duration }
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
			belongs_to :entry
			property :id, Serial
			property :start, Time, :nullable => false
			property :end, Time

			def duration
				end_time = self.end || Time.now
				(end_time - self.start)/60.0
			end

		end

		class Entry
			has 1, :activity
			has n, :records
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
		resources << Record

	end

	class Parser

		operations[:log].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:foreground) { |p| p.type = :bool } 
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:completion) { |p| p.type = :time } 
			o.parameter(:duration) { |p| p.type = :float }
		end

		operations[:select].modify do |o|
			o.parameter(:project)
			o.parameter(:version)
			o.parameter(:ref)
			o.parameter(:foreground) { |p| p.type = :bool } 
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
			o.parameter(:foreground) { |p| p.type = :bool } 
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
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
			o.parameter(:track) { |p| p.type = :integer; p.required = true}
			o.parameter(:from) { |p| p.type = :time; p.required = true}
			o.parameter(:to) { |p| p.type = :time }
		end

		operation(:untrack) do |o|
			o.parameter(:track) { |p| p.type = :integer; p.required = true}
			o.parameter(:from) { |p| p.type = :time}
			o.parameter(:to) { |p| p.type = :time}
		end

		special_attributes << :project
		special_attributes << :version
		special_attributes << :ref
		special_attributes << :completion
		special_attributes << :duration
		special_attributes << :foreground

	end

	class Engine


		def start(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			entry.activity.reload
			entry.records.reload
			raise EngineError, "Selected activity is already started." if entry.activity.started?
			raise EngineError, "Selected activity has been completed." if entry.activity.completed?
			started = Repository::Entry.all('activity.tracking' => 'started', 'activity.foreground' => true) 
			# There should only be one started foreground activity at a time, but it's better to be safe than sorry...
			started.each { |a| pause_activity a if entry.activity.foreground == true }
			entry.activity.tracking = 'started'
			Repository::Record.create(:entry_id => entry.id, :start => Time.now) 	
			entry.save
			entry
		end

		def finish(index=nil)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1] if index
			raise EngineError, "Invalid index #{i}" unless entry
			# if no index specified, get the first (and only) started activity.
			entry = Repository::Entry.first('activity.tracking' => 'started', :foreground => true) unless entry 
			raise EngineError, "No activities started." unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			entry.activity.reload
			entry.records.reload
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			raise EngineError, "Selected activity is already completed." if entry.activity.completed?
			# Verify if there's any open record
			open = Repository::Record.first(:entry_id => entry.id, :end => nil)
			if open then
				open.end = Time.now
				open.save
			end
			entry.activity.track
			entry.activity.tracking = 'completed'
			entry.activity.completion = Time.now
			entry.save
			entry
		end

		def pause(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			entry.activity.reload
			entry.records.reload
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			raise EngineError, "Selected activity is already #{entry.activity.tracking}." unless entry.activity.started?
			pause_activity entry
			entry
		end

		def track(index, from, to=nil)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			entry.activity.reload
			entry.records.reload
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			started = Repository::Record.all(:activity_id => entry.activity_id, :start.gt => from)
			ended = Repository::Record.all(:activity_id => entry.activity_id, :end.lt => to)
			raise EngineError, "Operation not allowed (overlapping records)." unless started.blank? && ended.blank?
			Repository::Record.create :entry_id => entry.id, :start => from, :end => to
			if !to then
				entry.activity.tracking  = 'started'
				entry.save
			end
			entry
		end

		def untrack(index, from=nil, to=nil)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			entry.activity.reload
			entry.records.reload
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			attributes = {:entry_id => entry.id}
			attributes.merge! :start.gt => from, :end.lt => to  if from || to
			records = Repository::Record.all(attributes)
			raise EngineError, "No tracking records in the specified interval." if records.blank?
			records.each { |r| r.destroy }
			entry.records.reload
			entry
		end

		define_hook(:after_update) do |params|
			project = params[:attributes][:project]
			version = params[:attributes][:version]
			ref = params[:attributes][:ref]
			foreground = params[:attributes][:foreground]
			completion = params[:attributes][:completion]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if foreground || project || version || ref || completion || duration then	
				activity =  Repository::Activity.first(:entry_id => entry.id) || Repository::Activity.create(:entry_id => entry.id)  
				activity.project = entry.resource :project, project unless project.blank?
				activity.version = entry.resource :version, version unless version.blank?
				activity.ref = ref
				activity.foreground = foreground
				activity.completion = completion
				activity.duration = duration
				entry.activity = activity
				entry.save
			end
		end

		define_hook(:after_insert) do |params|
			project = params[:attributes][:project]
			version = params[:attributes][:version]
			ref = params[:attributes][:ref]
			tracking = params[:attributes][:tracking] || 'disabled'
			completion = params[:attributes][:completion]
			foreground = params[:attributes][:foreground]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if foreground || tracking || project || version || ref || completion || duration then	
				activity =  Repository::Activity.create(:entry_id => entry.id)	
				activity.project = entry.resource :project, project unless project.blank?
				activity.version = entry.resource :version, version unless version.blank?
				activity.ref = ref
				activity.tracking = tracking
				activity.completion = completion
				activity.foreground = (foreground == false) ? false : true
				activity.duration = duration
				entry.activity = activity
				entry.save
			end
		end

		private

		def pause_activity(entry, time=nil)
			raise EngineError, "Activity already paused" if entry.activity.paused?
			open = Repository::Record.first(:entry_id => entry.id, :end => nil)
			if open then
				open.end = time || Time.now
				open.save
			end
			entry.activity.tracking = 'paused'
			entry.activity.track
			entry.save
		end

		def complete_activity(entry, time=nil)
			raise EngineError, "Activity already completed" if entry.activity.completed?
			open = Repository::Record.first(:entry_id => entry.id, :end => nil)
			if open then
				open.end = time || Time.now
				open.save
			end
			entry.activity.tracking = 'completed'
			entry.activity.track
			entry.save
		end

		def start_activity(entry, time=nil)
			raise EngineError, "Activity already started" if entry.activity.started?
			Repository::Record.create(:entry_id => entry.id, :start => time || Time.now)
			entry.activity.tracking = 'started'
			entry.save
		end
	end

end
