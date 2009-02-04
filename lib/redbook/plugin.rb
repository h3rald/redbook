#!/usr/bin/env ruby

module RedBook

	class Plugin

		include Messaging


		def initialize(plugin_hash)
			@name = plugin_hash[:name]
			@file = plugin_hash[:file]
			@label = plugin_hash[:label]
			debug "#@name plugin loaded."
		end

		def init
			debug "Setting up #@name plugin..."	
			setup
			debug "Done."
		end

		def setup_actions
			nil
		end

		protected

		def create_table(table)
			model = table.to_s.singularize.camelize.to_sym
			name = table.to_s	
			begin
				Repository.const_get(model).first
			rescue
				Repository.const_get(model).auto_migrate!
				debug " -> Created #{name} table."
			end
		end


	end

	class PluginCollection

		class << self; attr_accessor :plugins; end

		@plugins = {}	
			

		def self.load_all
			dirs = []
			dirs << RedBook::LIB_DIR/'../plugins'
			dirs << RedBook::HOME_DIR/'.redbook-plugins'
			dirs << RedBook::HOME_DIR/'redbook-plugins'
			dirs.each do |d|
				if File.exists?(d) && File.directory?(d) then
					Pathname.new(d).each_entry do |f|
						p = self.load(d/f.to_s)
					end
				end
			end
		end

		def self.loaded?(name)
			return !@plugins[name].blank?
		end

		def self.load(file)
			if file.to_s =~ /\_plugin.rb$/ then
				if require(file.to_s) then
					name = file.basename.to_s.gsub!(/\_plugin.rb$/, '')
					plugin = {:name => name.camel_case, :file => file, :label => name.to_sym}
					@plugins[name.to_sym] = RedBook.const_get(:"#{plugin[:name]}Plugin").new plugin
					return @plugins[name.to_sym]
				end
			end
			return false
		end

	end
end
