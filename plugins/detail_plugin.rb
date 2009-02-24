#!/usr/bin/env ruby

module RedBook

	class DetailPlugin < Plugin
		def setup
			create_resource :items, :inventory => true
			create_resource :details
			create_resource :item_map
		end
	end

	class Repository 

		class Item 
			include DataMapper::Resource
			has n, :item_map
			has n, :entries, :through => :item_map, :mutable => true
			property :id, Serial
			property :name, String, :nullable => false, :unique => true
			property :type, String, :nullable => false
			storage_names[:default] = 'items'
		end

		class Detail
			include DataMapper::Resource
			belongs_to :entry
			property :id, Serial
			property :entry_id, Integer, :key => true
			property :name, String, :nullable => false, :unique => true
			property :type, String, :nullable => false
			storage_names[:default] = 'details'
		end

		class ItemMap 
			include DataMapper::Resource
			belongs_to :entry
			belongs_to :item
			property :entry_id, Integer, :key => true
			property :item_id, Integer, :key => true
			storage_names[:default] = "item_map"
		end

		class Entry
			has n, :item_map
			has n, :items, :through => :item_map, :mutable => true 
			has n, :details

			def get_item(t)
				return nil if items.blank?
				result = items.select{|i| i.type == t }
				return (result.blank?) ? nil : result[0]
			end

			def set_item(i)
				raise RepositoryError, "Item must be a pair." unless i.pair?
				old_item = get_item(i.name)
				unless old_item == i.value then
					# Delete the current association, if necessary
					ItemMap.first(:entry_id => self.id, :item_id => old_item.id).destroy unless old_item.blank?
					# Add item
					new_item = Item.first(:type => i.name.to_s)||Item.create(:type => i.name.to_s, :name => i.value.to_s)
					im = ItemMap.create(:entry_id => self.id, :item_id => new_item.id)
					im.save
				end
			end

			def get_detail(t)
				return nil if details.blank?
				result = details.select{|i| d.type == t }
				return (result.blank?) ? nil : result[0]
			end

			def detail=(i)
				raise RepositoryError, "Detail must be a pair." unless i.pair?
				old_detail = get_detail(i.name)
				unless old_detail == i.value then
					# Delete the current association, if necessary
					old_detail.destroy unless old_item.blank?
					# Add detail
					new_detail = Detail.create(:type => i.name.to_s, :name => i.value.to_s, :entry_id => self.id)
				end
			end

		end
	end

	class Parser

		# Add details
		RedBook.config.plugins.detail.details.each do |d|
			operations[:log].parameter(d) { |p| p.special = true }
			operations[:update].parameter(d) { |p| p.special = true }
			operations[:select].parameter(d) { |p| p.special = true }
		end

		# Add items 
		RedBook.config.plugins.detail.items.each do |i|
			operations[:log].parameter(i) { |p| p.special = true }
			operations[:update].parameter(i) { |p| p.special = true }
			operations[:select].parameter(i) { |p| p.special = true }
		end

	end

	class Engine

		define_hook(:after_insert) do |params|
			details = {}
			items = {}
			entry = params[:entry]
			params[:attributes].each_pair do |k, v|
				if RedBook.config.plugins.detail.details.include? k then
					entry.set_detail k => v	
				elsif RedBook.config.plugins.detail.items.include? k then
					entry.set_detail k => v	
				end
			end
			continue
		end

		define_hook(:after_update) do |params|
			details = {}
			items = {}
			entry = params[:entry]
			params[:attributes].each_pair do |k, v|
				if RedBook.config.plugins.detail.details.include? k then
					entry.set_detail k => v	
				elsif RedBook.config.plugins.detail.items.include? k then
					entry.set_item k => v	
				end
			end
			continue
		end

		define_hook(:after_relog) do |params|
			entry = params[:entry]
			attributes = params[:attributes]
			add_attribute = lambda do |field, attributes|
				attributes[field] = entry.send field if entry.respond_to? field
			end
			fields = RedBook.config.plugins.detail.details + RedBook.config.plugins.detail.items
			fields.each { |f| add_attribute.call f, attributes}
			continue
		end
	end

end
