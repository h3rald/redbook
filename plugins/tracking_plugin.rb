#!/usr/bin/env ruby

module RedBook

	class TrackingPlugin < Plugin
		def setup
			create_resource :activities
			create_resource :records
		end
	end

	operations[:log].modify do
		parameter(:foreground) { type :bool; set :special } 
		parameter(:tracking) { type :enum; restrict_to 'started', 'disabled', 'paused', 'completed' }
		parameter(:start) { type :time; set :special } 
		parameter(:end) { type :time; set :special } 
		parameter(:duration) { type :float; set :special }
	end

	operations[:select].modify do
		parameter(:foreground) { type :bool; rewrite_as 'activity.foreground'; set :special } 
		parameter(:tracking) { type :list; restrict_to 'started', 'disabled', 'paused', 'completed'; rewrite_as 'activity.tracking.in' }
		parameter(:started_before) { type :time; rewrite_as 'activity.start.lt'} 
		parameter(:started_after) { type :time; rewrite_as 'activity.start.gt'} 
		parameter(:ended_before) { type :time; rewrite_as 'activity.end.lt'} 
		parameter(:ended_after) { type :time; rewrite_as 'activity.end.gt'} 
		parameter(:longer_than) { type :float; rewrite_as 'activity.duration.gt'}
		parameter(:shorter_than) { type :float; rewrite_as 'activity.duration.lt'}
	end

	operations[:update].modify do
		parameter(:foreground) { type :bool; set :special } 
		parameter(:tracking) { type :enum; restrict_to 'started', 'disabled', 'paused', 'completed'}
		parameter(:start) { type :time; set :special} 
		parameter(:end) { type :time; set :special} 
		parameter(:duration) { type :float; set :special }
	end

	# New Operations

	operation(:start) { 
		target { type :integer; set :required}
		body { |params|
			@engine.start params[:start]
			info "Activity started."
		}
	}

	operation(:finish) {
		target { type :integer}
		body { |params|
			@engine.finish params[:finish]
			info "Activity completed."
		}
	}

	operation(:pause) {
		 target { type :integer; set :required }
		 body { |params|
			@engine.pause params[:pause]
			info "Activity paused."
		 }
	}

	operation(:track) {
		target { type :integer; set :required }
		parameter(:from) { type :time; set :required }
		parameter(:to) { type :time }
		body { |params|
			@engine.track params[:track], params[:from], params[:to]
			info "Done."
		}
	}

	operation(:untrack) {
		target { type :integer; set :required }
		parameter(:from) { type :time }
		parameter(:to) { type :time }
		body { |params|
			if params[:from].blank? && params[:to].blank? then
				return unless agree "Do you really want to disable tracking for this activity? "
			end
			@engine.untrack params[:untrack], params[:from], params[:to]
			info "Done."
		}
	}

	operation(:tracking) {
		target { type :intlist }
		body { |params|
			raise UIError, "Empty dataset." if @engine.dataset.blank?
			result = (params[:tracking].blank?) ? @engine.dataset : [].tap{|a| params[:tracking].each{|i| a << @engine.dataset[i-1]}}
			display result, :tracking => true if RedBook.output 
		}
	}

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

	class Emitter

		class CliHelper

			def activity(a, total=1, index=0)
				[padding(total, index)+index.to_s.cyan, activity_icon(a), a.text.cyan].join ' '  
			end

			def tracking(a, ttl=1, indx=0)
				"".tap do |result|
					result << "\n"
					result << padding(ttl, indx)+pad(indx)+"- "+pair({:start => a.activity.start.textualize})+' '+pair({:end => a.activity.end.textualize})+"\n"
					result << padding(ttl, indx)+pad(indx)+"- "+pair({:duration => a.activity.duration.textualize(RedBook.config.duration_format)})
					result << ' '
					result << "(#{a.activity.tracked_duration.textualize(RedBook.config.duration_format)})\n".cyan
					result << records(a, ttl, indx)
				end.chomp
			end

			def records(a, ttl=1, indx=0)
				"".tap do |result|
					if a.respond_to? :records then
						result << padding(ttl, indx)+pad(indx)+"=> Tracking Records:\n".dark_green
						a.records.each do |r|
							result << padding(ttl, indx)+pad(indx)+'- '+pair({:start => r.start.textualize})+' -> '+pair({:end => r.end.textualize})+"\n"
						end
					end
				end
			end

			def activity_icon(entry)
				case entry.activity.tracking
				when 'started'
					i = ">"
					m = :yellow
				when 'paused'
					i = "="
					m = :blue
				when 'completed'
					i = "#"
					m = :green
				else
					i = "*"
					m = :cyan
				end
				(entry.activity.foreground.blank?) ? "{#{i}}".send(m) : "[#{i}]".send(m)
			end
		end

		class TxtHelper

			def activity(entry, total=1, index=0)
				super(entry, total, index).uncolorize
			end

			def activity_tracking(entry, total=1, index=0)
				super(entry, total, index).uncolorize
			end

		end
	end

	class Engine


		def start(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{index}" unless entry
			entry.activity.reload
			raise EngineError, "Selected entry is not an activity." unless entry.resource_type == 'activity'
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
			raise EngineError, "Invalid index #{index}" unless entry
			entry.activity.reload
			raise EngineError, "Selected entry is not an activity." unless entry.resource_type == 'activity'
			raise EngineError, "Tracking is disabled for selected activity." if entry.activity.disabled?
			raise EngineError, "Selected activity is already completed." if entry.activity.completed?
			# Verify if there's any open record
			Engine.complete_activity entry
			entry
		end

		def pause(index)
			raise EngineError, "Empty dataset" if @dataset.blank?
			entry = @dataset[index-1]
			raise EngineError, "Invalid index #{index}" unless entry
			entry.activity.reload
			raise EngineError, "Selected entry is not an activity." unless entry.resource_type == 'activity'
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
			#raise EngineError, "Selected entry is not an activity." unless entry.resource_type == 'activity'
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
			raise EngineError, "Selected entry is not an activity." unless entry.resource_type == 'activity'
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
			if entry.resource_type == 'activity' || foreground != nil || a_end || a_start || duration then	
				activity =  Repository::Activity.first(:entry_id => entry.id) || Repository::Activity.create(:entry_id => entry.id)  
				activity.foreground = foreground unless foreground == nil
				activity.end = a_end if attributes.has_key? :end
				activity.start = a_start if attributes.has_key? :start
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
				entry.save rescue nil
			end
			continue
		end

		define_hook(:after_insert) do |params|
			tracking = params[:attributes][:tracking]
			a_end = params[:attributes][:end]
			a_start = params[:attributes][:start]
			foreground = params[:attributes][:foreground]
			duration = params[:attributes][:duration]
			entry = params[:entry]
			if entry.resource_type == 'activity' || foreground || tracking || a_end || a_start || duration then	
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
			continue
		end

		define_hook(:after_each_delete) do |params|
			entry = params[:entry]
			a = Repository::Activity.first(:entry_id => entry.id)
			a.destroy unless a.blank?
			rs = Repository::Record.all(:entry_id => entry.id)
			rs.each { |r| r.destroy }
			continue
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
			entry.activity.save
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
			entry.activity.save
		end

		def Engine.start_activity(entry, time=nil)
			raise EngineError, "Activity already started" if entry.activity.started?
			time ||= Time.now
			Repository::Record.create(:entry_id => entry.id, :start => time)
			entry.activity.start = time
			entry.activity.tracking = 'started'
			entry.activity.save
		end
	end

end
