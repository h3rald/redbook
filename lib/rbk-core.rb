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

lib = Pathname(__FILE__).dirname.expand_path
core = lib/'rbk-core'


module RedBook
	
	class GenericError < RuntimeError; {} end;
	class EngineError < RuntimeError; {} end;
	class EmitterError < RuntimeError; {} end;
	class ParserError < RuntimeError; {} end;
	
	CORE_DIR = Pathname(__FILE__).dirname.expand_path
	HOME_DIR = RUBY_PLATFORM =~ /win32/i ? ENV['HOMEPATH'] : ENV['HOME']
	
	class << self; attr_accessor :debug, :silent; end
	
	@debug = false
	@silent = false
	
end

require core/'hook'
require core/'message'
require core/'repository'
require core/'engine'
require core/'emitter'
require core/'parser'
