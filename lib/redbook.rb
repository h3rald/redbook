#!/usr/bin/env ruby
# RedBook Core
#
# Web Site:: http://www.h3rald.com/redbook
# Author::    Fabio Cevasco (mailto:h3rald@h3rald.com)
# Copyright:: Copyright (c) 2007-2009 Fabio Cevasco
# License::   BSD


require 'rubygems'
require 'pathname'
require 'yaml'
require 'methodchain'
require 'extlib'
require 'dm-core'
require 'configatron'
require 'observer'
require 'erubis/tiny'
require 'chronic'
require 'highline/system_extensions'
require 'highline/import'

lib = Pathname(__FILE__).dirname.expand_path
core = lib/'redbook'

module RedBook
	
	class GenericError < RuntimeError; {} end;
	class EngineError < RuntimeError; {} end;
	class EmitterError < RuntimeError; {} end;
	class ParserError < RuntimeError; {} end;
	class UIError < RuntimeError; {} end;
	class PluginError < RuntimeError; {} end;
	
	LIB_DIR = Pathname(__FILE__).dirname.expand_path
	HOME_DIR = RUBY_PLATFORM =~ /win32/i ? '' : ENV['HOME']
	
	class << self; attr_accessor :debug, :output, :colors, :inventory_tables, :config; end

	@config = configatron
end

require lib/'../config'
require RedBook::HOME_DIR/'../redbook_config' if File.exists? RedBook::HOME_DIR/'../redbook_config'

require 'rawline' if RedBook::config.completion

module RedBook
	
	class << self; attr_accessor :debug, :output, :colors, :inventory_tables, :config; end
	
	@debug = @config.debug
	@output = @config.output
	@inventory_tables = []
	
	if RUBY_PLATFORM =~ /win32/i then
		begin 
			require 'win32console'
			@colors = true
		rescue Exception => e
			@colors = false
		end
	else
		@colors = true
	end

	@colors = (@colors == true && @config.colors)
	
end



require core/'system_extensions'
require core/'hook'
require core/'message'
require core/'repository'
require core/'engine'
require core/'emitter'
require core/'parser'
require core/'operations'
require core/'cli'
require core/'plugin'

RedBook::PluginCollection.load_all
