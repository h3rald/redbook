#!/usr/bin/env ruby

module RedBook

	class DetailPlugin < Plugin
		def setup
			create_resource :items, :inventory => true
			create_resource :details
			create_resource :item_map
			RedBook.config.items.each { |i| completion_for i.to_s.plural.to_sym, [i] }
		end
	end

	# Add details
	RedBook.config.details.each do |d|
		operations[:log].parameter(d) { set :special }
		operations[:update].parameter(d) { set :special }
		operations[:select].parameter(d) { set :special }
	end

	# Add items 
	RedBook.config.items.each do |i|
		operations[:log].parameter(i) { set :special }
		operations[:update].parameter(i) { set :special }
		operations[:select].parameter(i) { set :special }
	end

	operation(:detail) {
		target { type :intlist }
		body { |params|
			raise CliError, "Empty dataset." if @engine.dataset.blank?
			result = (params[:detail].blank?) ? @engine.dataset : [].tap{|a| params[:detail].each{|i| a << @engine.dataset[i-1]}}
			display result, :detail => true if RedBook.output 
		}
	}

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

	class Emitter

		class CliHelper
			def details(entry, total=1, index=0)
				entry.then{details}.map{|d| padding(total, index)+pad(index)+'- '+pair(d.detail_type => d.name)}.join "\n"
			end

			def items(entry, total=1, index=0)
				entry.then{items}.map{|i| padding(total, index)+pad(index)+'- '+pair(i.item_type => i.name)}.join "\n"
			end

			def detail(entry, total=1, index=0)
				"".tap do |result|
					if entry.then{items}.length > 0 || entry.then{details}.length > 0 then
						result << "\n"
						result << items(entry, total, index)
						result << "\n"
						result << details(entry, total, index)
					end
				end.chomp
			end

		end

		class TxtHelper
			
			def details(entry, total=1, index=0)
				entry.then{details}.map{|d| '  '+'- '+pair(d.detail_type => d.name)}.join "\n"
			end

			def items(entry, total=1, index=0)
				entry.then{items}.map{|i| '  '+'- '+pair(i.item_type => i.name)}.join "\n"
			end

			def detail(entry, total=1, index=0)
				super(entry, total, index)
			end

		end

		class TxtH

			def detail(entry, total=1, index=0)
				super(entry, total, index).uncolorize
			end
		end

	end

	class Engine

		define_hook(:after_refresh_table) do |params|
			table = params[:table]
			inventory = params[:inventory]
			if table == :items then
				inventory.delete(table)
				types = Repository.query("SELECT DISTINCT item_type FROM items")
				types.each do |t|
					data = Repository::Item.all(:item_type => t)
					inventory[t.plural.to_sym] = data.map{|d| d.name} unless data.blank?
				end
			end
			continue
		end

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
				res = {}.tap do |s|
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
