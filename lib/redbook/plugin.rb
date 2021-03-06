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
			setup
			load_macros
		end

		def setup
			nil
		end

		protected

		def load_macros
			macros = RedBook.config.macros.send(@label) || {}
			macros.each_pair { |k, v| RedBook.macro k, v }
		end

		def create_resource(table, options={})
			model = table.to_s.singularize.camel_case.to_sym
			name = table.to_s	
			begin
				klass = Repository.const_get(model)
				RedBook::Repository.resources << klass
				klass.first
			rescue
				Repository.const_get(model).auto_migrate!
				debug " -> Created #{name} table."
			end
			RedBook.inventory_tables << table if options[:inventory] == true 
		end

		def completion_for(table, directives=[])
			RedBook::Cli.define_hook(:setup_completion) do |params|
				matches = params[:matches]
				c = params[:cli]
				regexps = {}.tap do |rx|
					dirs = directives.map{ |o| o.to_s }.join('|')
					rx[:directives] = /(#{dirs}) (([a-zA-Z0-9+_-]+)\s?)*$/
					rx[:rename] = /^rename #{table.to_s.singular} -from (([a-zA-Z0-9+_-]+)\s?)*$/
				end
				if Rawline.editor.line.text.match(regexps[:directives]) || Rawline.editor.line.text.match(regexps[:rename]) then
					c.engine.inventory[table].each { |t| matches << t unless Rawline.editor.line.text.match t} if c.engine.inventory[table]
				end
				RedBook::Cli.stop_hooks_unless !matches.blank?
			end
		end

	end

	class PluginCollection

		class << self; attr_accessor :plugins; end

		@plugins = {}	


		def self.load_all
			dirs = RedBook.config.plugins.directories
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
				name = file.basename.to_s.gsub!(/\_plugin.rb$/, '')
				if RedBook.config.plugins.list.include? name.to_sym then
					if require(file.to_s) then
						plugin = {:name => name.camel_case, :file => file, :label => name.to_sym}
						@plugins[name.to_sym] = RedBook.const_get(:"#{plugin[:name]}Plugin").new plugin
						return @plugins[name.to_sym]
					end
				end
			end
			return false
		end

	end
end
