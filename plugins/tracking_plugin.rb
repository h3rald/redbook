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
			property :entry_id, Integer, :key => true
			property :ref, String
			property :completion, Time
			property :duration, Float
			storage_names[:default] = 'activities'

			alias set_duration duration 

			def duration
				# Duration attribute overrides effective duration
				return set_duration if set_duration
				entry = Repository::Entry.first(:entry_id => entry_id)
				type = entry.type
				end_time = completion || Time.now
				start_time = entry.timestamp
				calculated_duration = end_time - start_time
				if type == :process
					return  calculated_duration * 3600
				else
					# Collect all activities ended or started within current activity's timespan
					started_activities = Repository::Entry.all(:timestamp.gt => start_time, :timestamp.lt => end_time, 'activity.completion' => nil)
					finished_activities = Repository::Entry.all('activity.completion.gt' => start_time, 'activity.completion.lt' => end_time)
					# Reduce timespan from left
					finished_activities.each do |a|
						start_time = a.activity.completion if a.activity.completion > start_time
					end
					# Reduce timespan from right
					started_activities.each do |a|
						end_time = a.timestamp if a.timestamp > end_time
					end
					# Get activities started and finished within the restricted timespan
					contained_activities = Repository::Entry.all(:timestamp.gt => start_time, 'activity.completion.lt' => end_time)
					calculated_duration = end_time - start_time 
					timespans = []
					contained_activities.each do |a|
						start = a.timestamp
						finish = a.activity.completion
						timespans << {:start => start, :end => finish}
					end
					ts = timespans.dup
					timespans.each do |t1|
						timespans.each do |t2|
							# 1( 2[) ]
							if t2[:start] < t1[:end] && t2[:end] > t1[:end]
								t1[:end] = t2[:end]
								timespans.delete t2
							end
							# 2[ 1(] )
							if t2[:start] < t1[:start] && t2[:end] > t1[:start]
								t1[:start] = t2[:start]
								timespans.delete t2
							end
							# 1( 2[] )
							timespans.delete t2 if t1[:start] < t2[:start] && t1[:end] > t2[:end]
						end
						# remove from activity duration	
					 	calculated_duration -= t1[:end] - t1[:start]
					end
				end
				calculated_duration
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

		class Parser

			operations[:log].parameter(:project)
			operations[:log].parameter(:version)
			operations[:log].parameter(:ref)
			operations[:log].parameter(:completion) { |p| p.type = :time } 
			operations[:log].parameter(:duration) { |p| p.type = :integer }

			operations[:select].parameter(:project)
			operations[:select].parameter(:version)
			operations[:select].parameter(:ref)
			operations[:select].parameter(:longerthan) { |p| p.type = :time } 
			operations[:select].parameter(:shorterthan) { |p| p.type = :time } 
			operations[:select].parameter(:before) { |p| p.type = :time } 
			operations[:select].parameter(:after) { |p| p.type = :time } 

			operations[:select].post_parsing << lambda do |params| 
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

			operations[:update].parameter(:project)
			operations[:update].parameter(:version)
			operations[:update].parameter(:ref)
			operations[:update].parameter(:completion) { |p| p.type = :time } 
			operations[:update].parameter(:duration) { |p| p.type = :integer }

			special_attributes << :project
			special_attributes << :version
			special_attributes << :ref
			special_attributes << :completion
			special_attributes << :duration

		end

		class Engine

			define_hook(:after_update) do |params|
				project = params[:attributes][:project]
				version = params[:attributes][:version]
				ref = params[:attributes][:ref]
				completion = params[:attributes][:completion]
				duration = params[:attributes][:duration]
				entry = params[:entry]
				if project || version || ref || completion || duration then	
					activity =  Repository::Activity.first(:entry_id => entry.id) || Repository::Activity.create(:entry_id => entry.id)  
					activity.project = entry.resource :project, project unless project.blank?
					activity.version = entry.resource :version, version unless version.blank?
					activity.ref = ref
					activity.completion = completion
					activity.duration = duration
					activity.save
				end
			end

			define_hook(:after_insert) do |params|
				project = params[:attributes][:project]
				version = params[:attributes][:version]
				ref = params[:attributes][:ref]
				completion = params[:attributes][:completion]
				duration = params[:attributes][:duration]
				entry = params[:entry]
				if project || version || ref || completion || duration then	
					activity =  Repository::Activity.create(:entry_id => entry.id)	
					activity.project = entry.resource :project, project unless project.blank?
					activity.version = entry.resource :version, version unless version.blank?
					activity.ref = ref
					activity.completion = completion
					activity.duration = duration
					activity.save
				end
			end


		end

	end




