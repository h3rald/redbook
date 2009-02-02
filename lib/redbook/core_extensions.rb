#!/usr/bin/env ruby

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

	def camelize
		Extlib::Inflection.camelize self
	end
	
	def plural
		Extlib::Inflection.plural self
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
		RedBook.colors ? "#{color_code}#{text}\e[0m" : text
	end
end

