#!/usr/bin/env ruby

module RedBook

	inventory_tables << :tags

	class TaggingPlugin < Plugin

		def setup
			create_table :tagmap
			create_table :tags
		end
	end

	class Cli

		define_hook(:setup_completion) do |params|
			c = params[:cli]
			matches = params[:matches]
			regexps = {}
			regexps[:tags] = /:(tags|addtag|rmtag) (([a-zA-Z0-9+_-]+)\s?)*$/
			regexps[:rename_tags] = /:rename tags :from (([a-zA-Z0-9+_-]+)\s?)*$/
			if c.editor.line.text.match(regexps[:tags]) || c.editor.line.text.match(regexps[:rename_tags])   then
				c.engine.inventory[:tags].each { |t| matches << t unless c.editor.line.text.match t} if c.engine.inventory[:tags]
			end
		end
	end

	class Repository 

		class Tag
			include DataMapper::Resource
			has n, :tagmap
			has n, :entries, :through => :tagmap, :mutable => true
			property :id, Serial
			property :name, String, :nullable => false, :unique => true
			storage_names[:default] = 'tags'

		end

		class Entry
			has n, :tagmap
			has n, :tags, :through => :tagmap, :mutable => true 

			def tagged_with?(tags=nil)
				tags = [] unless tags
				tags = [tags] unless tags.is_a? Array
				entry_tags = []
				self.tags.each { |t| entry_tags << t.name }
				(entry_tags & tags).sort == tags.uniq.sort
			end

			def add_tag(t)
				tag = Repository::Tag.first(:name => t) || Repository::Tag.create(:name => t)
				tagmap = Repository::Tagmap.create :tag_id => tag.id, :entry_id => self.id
				self.tagmap << tagmap
				tagmap.save
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

		operation(:addtag) do |o|
			o.parameter(:to) { |p| p.type = :intlist }
			o.parameter(:addtag) { |p| p.type = :list }
		end

		operation(:rmtag) do |o|
			o.parameter(:from) { |p| p.type = :intlist }
			o.parameter(:rmtag) { |p| p.type = :list }
		end

		special_attributes << :tags

	end

	class Engine	

		def addtag(tags, indexes=nil)
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

		def rmtag(tags, indexes=nil)
			raise EngineError, "Empty dataset." if @dataset.blank?
			entries = get_selected_entries indexes
			entries.each do |e|
				tags.each do |t|
					if e.tagged_with? t then
						tag = Repository::Tagmap.first(:entry_id => e.id, :tag_id => Repository::Tag.first(:name => t).id)
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
		end

		define_hook(:after_update) do |params|
			tags = params[:attributes][:tags]
			entry = params[:entry]
			if tags then
				# Destroy all tag associations
				entry_tags = Repository::Tagmap.all(:entry_id => entry.id)
				entry_tags.each { |t| t.destroy }
				entry.tags.reload
				tags.each do |t|
					entry.add_tag t					
				end
			end
		end		

		define_hook(:before_each_delete) do |params|
			entry = params[:entry]
			unless entry.tags.blank? then
				# Destroy all tag associations
				entry_tags = Repository::Tagmap.all(:entry_id => entry.id)
				entry.tagmap.each { |t| t.destroy }
				entry.tags.reload
			end
		end

		define_hook(:after_select) do |params|
			tags = params[:attributes][:tags]
			i = 0
			dataset = params[:dataset]
			while i < dataset.length
				dataset[i] = nil unless dataset[i].tagged_with?(tags) 
				i = i+1
			end
			dataset.compact!
		end

		define_hook(:cleanup) do |params|
			if params[:tables].blank? || params[:tables].include?('tags') then
				tags = Repository::Tag.all
				tags.each do |t|
					tagmap = Repository::Tagmap.first(:tag_id => t.id)
					if tagmap.blank? then
						t.destroy
					end
				end
			end
		end

	end
end



