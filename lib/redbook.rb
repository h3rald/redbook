#!/usr/bin/env ruby
# RedBook Core
#
# Web Site:: http://www.h3rald.com/redbook
# Author::    Fabio Cevasco (mailto:h3rald@h3rald.com)
# Copyright:: Copyright (c) 2007-2009 Fabio Cevasco
# License::   BSD


require 'rubygems'
require 'pathname'
require 'extlib'
require 'yaml'
require 'dm-core'
require 'observer'
require 'erubis/tiny'
require 'chronic'
require 'highline/system_extensions'
require 'highline/import'
require 'rawline'

lib = Pathname(__FILE__).dirname.expand_path
core = lib/'redbook'


module RedBook
	
	class GenericError < RuntimeError; {} end;
	class EngineError < RuntimeError; {} end;
	class EmitterError < RuntimeError; {} end;
	class ParserError < RuntimeError; {} end;
	class CliError < RuntimeError; {} end;
	
	LIB_DIR = Pathname(__FILE__).dirname.expand_path
	HOME_DIR = RUBY_PLATFORM =~ /win32/i ? '' : ENV['HOME']
	
	class << self; attr_accessor :debug, :output, :colors, :inventory_tables; end
	
	@debug = false
	@output = true
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
	
end

require core/'core_extensions'
require core/'hook'
require core/'message'
require core/'repository'
require core/'engine'
require core/'emitter'
require core/'parser'
require core/'cli'
require core/'plugin'

RedBook::PluginCollection.load_all
