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
	HOME_DIR = RUBY_PLATFORM =~ /win32/i ? ENV['HOMEPATH'] : ENV['HOME']
	if RUBY_PLATFORM.match /win32/i then
		begin 
			require 'win32console'
			COLORS = true
		rescue Exception => e
			COLORS = false
		end
	else
		COLORS = true
	end
	
	class << self; attr_accessor :debug, :output; end
	
	@debug = false
	@output = true
	
end

class Symbol

	def textualize
		":#{self.to_s}"
	end
end

# The String class has been extended with some methods mainly for colorizing and encoding output.
class String

	def symbolize
		if self.match /^:[a-z]+/ then
			self.sub(':', '').to_sym
		else
			self.to_sym
		end
	end

	# Make the receiver red.
	def red; colorize(self, "\e[1;31m"); end

	# Make the receiver dark red.
	def dark_red; colorize(self, "\e[0;31m"); end

	# Make the receiver green.
	def green; colorize(self, "\e[1;32m"); end
	
	# Make the receiver dark green.
	def dark_green; colorize(self, "\e[0;32m"); end

	# Make the receiver yellow.
	def yellow; colorize(self, "\e[1;33m"); end

	# Make the receiver dark yellow.
	def dark_yellow; colorize(self, "\e[0;33m"); end

	# Make the receiver blue.
	def blue; colorize(self, "\e[1;34m"); end

	# Make the receiver dark blue.
	def dark_blue; colorize(self, "\e[0;34m"); end

	# Make the receiver magenta.
	def magenta; colorize(self, "\e[1;35m"); end

	# Make the receiver magenta.
	def dark_magenta; colorize(self, "\e[0;35m"); end

	# Make the receiver cyan.
	def cyan; colorize(self, "\e[1;36m"); end

	# Make the receiver dark cyan.
	def dark_cyan; colorize(self, "\e[0;36m"); end

	# Uncolorize string.
	def uncolorize;	self.gsub!(/\e\[\d[;0-9]*m/, '') end

	# Colorize the receiver according the given ASCII escape character sequence.
	# Thanks to: http://kpumuk.info/ruby-on-rails/colorizing-console-ruby-script-output/
	def colorize(text, color_code) 
		RedBook::COLORS ? "#{color_code}#{text}\e[0m" : text
	end
end

require core/'hook'
require core/'message'
require core/'repository'
require core/'engine'
require core/'emitter'
require core/'parser'
require core/'cli'
