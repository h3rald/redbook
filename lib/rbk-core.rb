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

lib = Pathname(__FILE__).dirname.expand_path
core = lib/'rbk-core'

class RedBookError < Exception; {} end;

module RedBook

	CORE_DIR = Pathname(__FILE__).dirname.expand_path/'rbk-core'
	HOME_DIR = RUBY_PLATFORM =~ /win32/i ? ENV['HOMEPATH'] : ENV['HOME']
	
	def self.setup
		@config = load_config
		@debug = false
	end

	def self.debug
		@debug	
	end

	def self.debug=(value)
		@debug = value	
	end

	def self.config
		@config
	end

	private 

	def self.load_config
		cfg = nil
		rbk_cfg = Pathname(__FILE__).dirname.expand_path/'../rbk-config.yaml'
		try_file = lambda { |f| return File.exists?(f) ? f : false }
		cfg = try_file.call(rbk_cfg)
		raise RedBookError, "Configuration file not found" unless cfg
		begin
			YAML.load_file cfg
		rescue Exception => e
			raise RedBookError, "Invalid configuration file '#{cfg}' [#{e.message}]"
		end
	end

end

require core/'message'
require core/'repository'
require core/'hook'
require core/'engine'
