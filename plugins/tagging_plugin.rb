#!/usr/bin/env ruby

module RedBook
	class Repository 
		
		class Tag
			include DataMapper::Resource
			has n, :tagmap
			has n, :entries, :through => :tagmap, :mutable => true#, :class_name => 'RedBook::Repository::Entry', :child_key => [:entry_id], :mutable => true
			property :id, Serial
			property :name, String, :nullable => false, :unique => true
			storage_names[:default] = 'tags'

		end

		class Entry
			has n, :tagmap
			has n, :tags, :through => :tagmap, :mutable => true #, :class_name => 'RedBook::Repository::Tag', :child_key => [:tag]
			
			def tagged_with(tags)
				return false if self.tags.blank?
				entry_tags = []
				self.tags.each { |t| entry_tags << t.name }
				(entry_tags & tags).length == tags.uniq.length
			end
				
		end

		class Tagmap
			include DataMapper::Resource
			belongs_to :entry
			belongs_to :tag
			property :entry_id, Integer, :key => true
			property :tag_id, Integer, :key => true
			storage_names[:default] = "tagmap"
		end

		resources << Tagmap
		resources << Tag

	end

	class Parser

		operations[:log].parameter(:tags) {|p| p.type = :list}
		operations[:select].parameter(:tags) {|p| p.type = :list}
		operations[:update].parameter(:tags) {|p| p.type = :list}

	end

	class Engine

		define_hook(:after_insert) do |params|
			tags = params[:attributes][:tags]
			entry = params[:entry]
			if tags then
				tags.each do |t|
					tag = Repository::Tag.create :name => t
					tagmap = Repository::Tagmap.create :tag_id => tag.id, :entry_id => entry.id
					entry.tagmap << tagmap
					entry.save
				end
			end
		end


		define_hook(:after_select) do |params|
			tags = params[:attributes][:tags]
			params[:dataset].each { |e| params[:dataset].delete e unless e.tagged_with tags}
		end

	end

	### Plugin Class

	class TaggingPlugin < Plugin

		def setup_actions
			begin
				Repository::Tagmap.first
			rescue
				Repository::Tagmap.auto_migrate!
				debug " -> Created tagmap table."
			end
			begin
				Repository::Tag.first
			rescue
				Repository::Tag.auto_migrate!
				debug " -> Created tags table."
			end
		end

	end
end



