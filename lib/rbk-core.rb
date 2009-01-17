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


module RedBook
	
	class GenericError < RuntimeError; {} end;
	class EngineError < RuntimeError; {} end;

	HOME_DIR = RUBY_PLATFORM =~ /win32/i ? ENV['HOMEPATH'] : ENV['HOME']
	
	def self.debug
		@debug	
	end

	def self.debug=(value)
		@debug = value	
	end

end

require core/'message'
require core/'repository'
require core/'hook'
require core/'engine'
