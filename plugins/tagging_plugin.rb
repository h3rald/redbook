#!/usr/bin/env ruby

module RedBook

	class TaggingPlugin < Plugin

		def setup
			create_resource :tag_map
			create_resource :tags, :inventory => true 
			completion_for :tags, [:tag, :untag, :tags]
		end
	end

	operations[:log].parameter(:tags) { type :list; set :special} 
	operations[:select].parameter(:tags) {type :list; set :special}
	operations[:update].parameter(:tags) {type :list; set :special}

	operation(:tag) {
		target { type :intlist }
		parameter(:as) { type :list }
		body { |params|
			@engine.tag params[:as], params[:tag]
			info "Done."
		}
	}

	operation(:untag) {
		target { type :intlist }
		parameter(:as) { type :list }
		body { |params|
			@engine.untag params[:as], params[:untag]
			info "Done."
		}
	}

	class Repository 

		class Tag
			include DataMapper::Resource
			has n, :tag_map
			has n, :entries, :through => :tag_map, :mutable => true
			property :id, Serial
			property :name, String, :nullable => false, :unique => true
			storage_names[:default] = 'tags'
		end

		class Entry
			has n, :tag_map
			has n, :tags, :through => :tag_map, :mutable => true 

			def tagged_with?(tags=nil)
				tags = [] unless tags
				tags = [tags] unless tags.is_a? Array
				entry_tags = []
				self.tags.each { |t| entry_tags << t.name }
				(entry_tags & tags).sort == tags.uniq.sort
			end

			def add_tag(t)
				tag = Tag.first(:name => t) || Tag.create(:name => t)
				tm = Repository::TagMap.create :tag_id => tag.id, :entry_id => self.id
				self.tag_map << tm
				tm.save
			end

		end

		class TagMap 
			include DataMapper::Resource
			belongs_to :entry
			belongs_to :tag
			property :entry_id, Integer, :key => true
			property :tag_id, Integer, :key => true
			storage_names[:default] = "tag_map"
		end
	end

	class Engine	

		def tag(tags, indexes=nil)
			raise EngineError, "Empty dataset." if @dataset.blank?
			entries = get_selected_entries indexes
			entries.each do |e|
				tags.each do |t|
					unless e.tagged_with? t then
						e.add_tag t
					end
				end
			end
		end

		def untag(tags, indexes=nil)
			raise EngineError, "Empty dataset." if @dataset.blank?
			entries = get_selected_entries indexes
			entries.each do |e|
				tags.each do |t|
					if e.tagged_with? t then
						tag = Repository::TagMap.first(:entry_id => e.id, :tag_id => Repository::Tag.first(:name => t).id)
						tag.destroy
						e.tags.reload
					end
				end
			end
		end

		define_hook(:after_insert) do |params|
			tags = params[:attributes][:tags]
			entry = params[:entry]
			if tags then
				tags.each do |t|
					entry.add_tag t					
				end
			end
			continue
		end

		define_hook(:after_update) do |params|
			tags = params[:attributes][:tags]
			entry = params[:entry]
			if tags then
				# Destroy all tag associations
				entry_tags = Repository::TagMap.all(:entry_id => entry.id)
				entry_tags.each { |t| t.destroy }
				entry.tags.reload
				tags.each do |t|
					entry.add_tag t					
				end
			end
			continue
		end		

		define_hook(:before_each_delete) do |params|
			entry = params[:entry]
			unless entry.tags.blank? then
				# Destroy all tag associations
				entry_tags = Repository::TagMap.all(:entry_id => entry.id)
				entry.tag_map.each { |t| t.destroy }
				entry.tags.reload
			end
			continue
		end

		define_hook(:filter_dataset) do |params|
			tags = params[:attributes][:tags]
			entry = params[:entry]
			result = (tags.blank?) ? true : entry.tagged_with?(tags)
			stop_hooks_unless result
		end
	end
end
