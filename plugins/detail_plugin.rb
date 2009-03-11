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
			property :item_type, String, :nullable => false
			storage_names[:default] = 'items'
		end

		class Detail
			include DataMapper::Resource
			belongs_to :entry
			property :id, Serial
			property :entry_id, Integer, :key => true
			property :name, String, :nullable => false, :unique => true
			property :detail_type, String, :nullable => false
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

			def get_field(f, raw=false)
				(f.in? RedBook.config.details) ? get_detail(f, raw) : get_item(f, raw)
			end

			def set_field(f)
				raise RepositoryError, "Field must be a pair." unless i.pair?
				(f.name.in? RedBook.config.details) ? set_detail(f) : set_item(f)
			end

			def get_item(t, raw=false)
				return nil if self.items.blank?
				result = self.items.select{|i| i.item_type == t.to_s }
				return (result.blank?) ? nil : ((raw) ? result[0] : result[0].name)
			end

			def set_item(i)
				old_item = get_item(i.name, true)
				if old_item.blank? || old_item.name != i.value then
					# Delete the current association, if necessary
					ItemMap.first(:entry_id => self.id, :item_id => old_item.id).destroy unless old_item.blank?
					# Add item
					new_item = Item.first(:item_type => i.name.to_s, :name => i.value.to_s)||Item.create(:item_type => i.name.to_s, :name => i.value.to_s)
					im = ItemMap.create(:entry_id => self.id, :item_id => new_item.id)
					im.save
					self.items.reload
				end
			end

			def get_detail(t, raw=false)
				return nil if self.details.blank?
				result = self.details.select{|d| d.detail_type == t.to_s }
				return (result.blank?) ? nil : ((raw) ? result[0] : result[0].name)
			end

			def set_detail(i)
				old_detail = self.get_detail(i.name, true)
				if old_detail.blank? || old_detail.name != i.value then
					# Delete the current association, if necessary
					old_detail.destroy unless old_detail.blank?
					# Add detail
					new_detail = Detail.create(:detail_type => i.name.to_s, :name => i.value.to_s, :entry_id => self.id)
					self.details.reload
				end
			end

		end
	end

	class Parser

		# Add details
		RedBook.config.details.each do |d|
			operations[:log].parameter(d) { |p| p.special = true }
			operations[:update].parameter(d) { |p| p.special = true }
			operations[:select].parameter(d) { |p| p.special = true }
		end

		# Add items 
		RedBook.config.items.each do |i|
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
				if RedBook.config.details.include? k then
					entry.set_detail k => v	
				elsif RedBook.config.items.include? k then
					entry.set_item k => v	
				end
			end
			continue
		end

		define_hook(:after_update) do |params|
			details = {}
			items = {}
			entry = params[:entry]
			params[:attributes].each_pair do |k, v|
				if RedBook.config.details.include? k then
					entry.set_detail k => v	
				elsif RedBook.config.items.include? k then
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
			fields = RedBook.config.details + RedBook.config.items
			fields.each { |f| add_attribute.call f, attributes}
			continue
		end

		define_hook(:before_each_delete) do |params|
			entry = params[:entry]
			unless entry.items.blank? then
				# Destroy all associations
				entry_items = Repository::ItemMap.all(:entry_id => entry.id)
				entry.item_map.each { |i| i.destroy }
				entry.items.reload
			end
			unless entry.details.blank? then
				# Destroy all associations
				Repository::Detail.all(:entry_id => entry.id).each {|d| d.destroy}
				entry.details.reload
			end
			continue
		end

		define_hook(:filter_dataset) do |params|
			attrs = params[:attributes]
			entry = params[:entry]
			get_stuff = lambda do |stuff| 
				res = returning Hash.new do |s|
					stuff.each do |i|
						s[i] = attrs[i] unless attrs[i].blank?
					end
				end
			end
			details = get_stuff.call RedBook.config.details
			items = get_stuff.call RedBook.config.items
			check_details = lambda do
				res = true
				details.each_pair do |k, v|
					break unless res = (entry.get_detail(k) =~ /#{Regexp.escape(v)}/)
				end
				res
			end
			check_items = lambda do
				res = true
				items.each_pair do |k, v|
					break unless res = (entry.get_item(k) == v)
				end
				res
			end
			result = (details.blank? ? true : check_details.call) && (items.blank? ? true : check_items.call)
			stop_hooks_unless result
		end
	end
end
