#!/usr/bin/env ruby

module RedBook

	class TrackingPlugin < Plugin
		class << self; attr_accessor :add_resources; end

		def setup
			create_resource :activities
			create_resource :records
		end
	end

	class Cli

		def start_operation(params)
			@engine.start params[:start]
			info "Activity started."
		end

		def finish_operation(params)
			@engine.finish params[:finish]
			info "Activity completed."
		end

		def pause_operation(params)
			@engine.pause params[:pause]
			info "Activity paused."
		end

		def track_operation(params)
			@engine.track params[:track], params[:from], params[:to]
			info "Done."
		end

		def untrack_operation(params)
			if params[:from].blank? && params[:to].blank? then
				return unless agree "Do you really want to disable tracking for this activity? "
			end
			@engine.untrack params[:untrack], params[:from], params[:to]
			info "Done."
		end
	end

	class Repository

		class Activity
			include DataMapper::Resource
			belongs_to :entry 
			property :entry_id, Integer, :key => true
			property :foreground, Boolean
			property :start, Time
			property :end, Time
			property :duration, Float
			property :tracking, String
			storage_names[:default] = 'activities'

			def track
				return if disabled?
				self.duration = track_time
			end

			def tracked_duration
				track_time
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

			def valid_time?(time=nil)
				entry = Repository::Entry.first(:id => entry_id)
				return true if entry.activity.start.blank? && entry.activity.end.blank?
				entry.activity.start.to_time < time && (entry.activity.end.blank? || entry.activity.end.to_time > time)  
			end

			private

			def track_time
				records = Repository::Record.all(:entry_id => entry_id)
				result = 0
				records.each { |r| result += r.duration }
				result = (self.end - self.start)/60.0 if result == 0 && !self.start.blank? && !self.end.blank? # Simple tracking: end - start
				result
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

	end

	class Parser

		operations[:log].modify do |o|
			o.parameter(:foreground) { |p| p.type = :bool } 
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:start) { |p| p.type = :time } 
			o.parameter(:end) { |p| p.type = :time } 
			o.parameter(:duration) { |p| p.type = :float }
		end

		operations[:select].modify do |o|
			o.parameter(:foreground) { |p| p.type = :bool } 
			o.parameter(:tracking) { |p| p.type = :list; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:started_before) { |p| p.type = :time; p.rewrite_as 'activity.start.lt'} 
			o.parameter(:started_after) { |p| p.type = :time; p.rewrite_as 'activity.start.gt'} 
			o.parameter(:ended_before) { |p| p.type = :time; p.rewrite_as 'activity.end.lt'} 
			o.parameter(:ended_after) { |p| p.type = :time; p.rewrite_as 'activity.end.gt'} 
			o.parameter(:longer_than) { |p| p.type = :float; p.rewrite_as 'activity.duration.gt'}
			o.parameter(:shorter_than) { |p| p.type = :float; p.rewrite_as 'activity.duration.lt'}
		end

		operations[:update].modify do |o|
			o.parameter(:foreground) { |p| p.type = :bool } 
			o.parameter(:tracking) { |p| p.type = :enum; p.values = ['started', 'disabled', 'paused', 'completed'] }
			o.parameter(:start) { |p| p.type = :time } 
			o.parameter(:end) { |p| p.type = :time } 
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
			o.parameter(:untrack) { |p| p.type = :integer; p.required = true}
			o.parameter(:from) { |p| p.type = :time}
			o.parameter(:to) { |p| p.type = :time}
		end

		special_attributes << :start
		special_attributes << :end
		special_attributes << :duration
		special_attributes << :foreground


	end

	class Engine


		def start(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			raise EngineError, "Selected activity is already started." if entry.activity.started?
			raise EngineError, "Selected activity has been completed." if entry.activity.completed?
			started = Repository::Entry.all('activity.tracking' => 'started', 'activity.foreground' => true) 
			# There should only be one started foreground activity at a time, but it's better to be safe than sorry...
			started.each { |a| Engine.pause_activity a if entry.activity.foreground == true }
			Engine.start_activity entry
			entry
		end

		def finish(index=nil)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1] if index
			raise EngineError, "Invalid activity or no activity specified." unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			raise EngineError, "Selected activity is already completed." if entry.activity.completed?
			# Verify if there's any open record
			Engine.complete_activity entry
			entry
		end

		def pause(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			raise EngineError, "Selected activity is already #{entry.activity.tracking}." unless entry.activity.started?
			Engine.pause_activity entry
			entry
		end

		def track(index, from, to=nil)
			raise EngineError, "Start time earlier than end time" if !to.blank? && from > to
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{i}" unless entry
			raise EngineError, "Selected entry is not an activity." unless entry.type == 'activity'
			entry.activity.reload
			entry.records.reload
			started = Repository::Record.all(:entry_id => entry.id, :start.lt => from, :end.gt => from)
			ended = Repository::Record.all(:entry_id => entry.id, :end.gt => to)
			raise EngineError, "Operation not allowed (overlapping records)." unless started.blank? && ended.blank?
			raise EngineError, "Invalid start time." unless entry.activity.valid_time? from
			raise EngineError, "Invalid end time." unless entry.activity.valid_time?(to) || to.blank? 
			Repository::Record.create :entry_id => entry.id, :start => from, :end => to
			entry.activity.track
			if !to then
				start_activity entry
			elsif entry.activity.tracking != 'completed'
				entry.activity.tracking  = 'paused'
			end
			entry.save
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
			attributes.merge!(:start.gt => from, :end.lt => to)  if from || to
			records = Repository::Record.all(attributes)
			raise EngineError, "No tracking records in the specified interval." if records.blank?
			records.each { |r| r.destroy }
			if from.blank? && to.blank? then
				entry.activity.tracking = 'disabled'
			else
				entry.activity.track
			end
			entry.save
		end

		define_hook(:after_update) do |params|
			attributes = params[:attributes]
			foreground = attributes[:foreground]
			a_end = attributes[:end]
			a_start = attributes[:start]
			duration = attributes[:duration]
			entry = params[:entry]
			if entry.type == 'activity' || foreground != nil || a_end || a_start || duration then	
				activity =  Repository::Activity.first(:entry_id => entry.id) || Repository::Activity.create(:entry_id => entry.id)  
				activity.foreground = foreground unless foreground == nil
				activity.end = a_end unless attributes.null_key? :end
				activity.start = a_start unless attributes.null_key? :start
				raise EngineError, "Start time is later than end time." if !activity.end.blank? && !activity.start.blank? && activity.start > activity.end
				if activity.end == nil then
					pause_activity(entry) if activity.started?
				elsif !a_end.blank?
					complete_activity entry
				end
				unless duration.blank? then
					activity.duration = duration
					activity.tracking = 'disabled'
				end
				activity.track 
				entry.activity = activity
				entry.save
			end
			{:value => nil, :stop => false}
		end

		define_hook(:after_insert) do |params|
			tracking = params[:attributes][:tracking]
			a_end = params[:attributes][:end]
			a_start = params[:attributes][:start]
			foreground = params[:attributes][:foreground]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if entry.type == 'activity' || foreground || tracking || a_end || a_start || duration then	
				tracking ||= 'disabled'
				activity =  Repository::Activity.create(:entry_id => entry.id)	
				activity.tracking = tracking
				activity.end = a_end
				activity.start = a_start
				raise EngineError, "Start time is later than end time."  if !activity.end.blank? && !activity.start.blank? && activity.start > activity.end
				activity.foreground = (foreground == false) ? false : true
				activity.duration = duration
				entry.activity = activity
				entry.save
			end
			{:value => nil, :stop => false}
		end

		define_hook(:after_relog) do |params|
			entry = params[:entry]
			attributes = params[:attributes]
			add_attribute = lambda do |field, attributes|
				attributes[field] = entry.send field if entry.respond_to? field
			end
			fields = [:start, :tracking, :end, :foreground, :duration]
			fields.each { |f| add_attribute.call f, attributes}
			{:value => nil, :stop => false}
		end

		define_hook(:after_each_delete) do |params|
			entry = params[:entry]
			a = Repository::Activity.first(:entry_id => entry.id)
			a.destroy unless a.blank?
			rs = Repository::Record.all(:entry_id => entry.id)
			rs.each { |r| r.destroy }
			{:value => nil, :stop => false}
		end

		def Engine.pause_activity(entry, time=nil)
			raise EngineError, "Activity already paused" if entry.activity.paused?
			open = Repository::Record.first(:entry_id => entry.id, :end => nil)
			if open then
				open.end = time || Time.now
				open.save
			end
			entry.activity.tracking = 'paused'
			entry.activity.track
			entry.save
			{:value => nil, :stop => false}
		end

		def Engine.complete_activity(entry, time=nil)
			raise EngineError, "Activity already completed" if entry.activity.completed?
			open = Repository::Record.first(:entry_id => entry.id, :end => nil)
			if open then
				open.end = time || Time.now
				open.save
			end
			time ||= Time.now
			entry.activity.end = time 
			entry.activity.tracking = 'completed'
			entry.activity.track
			entry.save
		end

		def Engine.start_activity(entry, time=nil)
			raise EngineError, "Activity already started" if entry.activity.started?
			time ||= Time.now
			Repository::Record.create(:entry_id => entry.id, :start => time)
			entry.activity.start = time
			entry.activity.tracking = 'started'
			entry.save
		end
	end

end
