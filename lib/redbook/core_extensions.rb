#!/usr/bin/env ruby

class Symbol

	# Converts the receiver to a string (:select becomes ":select").
	def textualize
		":#{self.to_s}"
	end
end

class Hash
	def null_key?(attr)
		self.has_key?(attr) && self[attr] == nil
	end
end

class DateTime
	def textualize(format=RedBook.config.time_format)
		strftime(format)
	end
end

class Time
	def textualize(format=RedBook.config.time_format)
		strftime(format)
	end
end

class Numeric
	def textualize(format=nil)
		mult = 1
		case format
		when :minutes
			mult=60
		when :hours
			mult=3600
		when :days
			mult=3600*24
		else
			mult=1
		end
		(((self/mult)*100).round/100.0).to_s
	end
end

class NilClass
	def textualize(format=nil)
		"n/a"
	end
end

# The String class has been extended with some methods mainly for colorizing and encoding output.
class String

	# Converts the receiver to a symbol. It works like <tt>to_sym</tt>,
	# but ":select" becomes :select instead of :":select". 
	def symbolize
		if self.match /^:[a-z]+/ then
			self.sub(':', '').to_sym
		else
			self.to_sym
		end
	end

	# Makes the receiver plural
	def plural
		Extlib::Inflection.plural self
	end

	# Makes the receiver singular
	def singular
		Extlib::Inflection.singular self
	end

	# Makes the receiver red.
	def red; colorize(self, "\e[1;31m"); end

	# Makes the receiver dark red.
	def dark_red; colorize(self, "\e[0;31m"); end

	# Makes the receiver green.
	def green; colorize(self, "\e[1;32m"); end
	
	# Makes the receiver dark green.
	def dark_green; colorize(self, "\e[0;32m"); end

	# Makes the receiver yellow.
	def yellow; colorize(self, "\e[1;33m"); end

	# Makes the receiver dark yellow.
	def dark_yellow; colorize(self, "\e[0;33m"); end

	# Makes the receiver blue.
	def blue; colorize(self, "\e[1;34m"); end

	# Makes the receiver dark blue.
	def dark_blue; colorize(self, "\e[0;34m"); end

	# Makes the receiver magenta.
	def magenta; colorize(self, "\e[1;35m"); end

	# Makes the receiver magenta.
	def dark_magenta; colorize(self, "\e[0;35m"); end

	# Makes the receiver cyan.
	def cyan; colorize(self, "\e[1;36m"); end

	# Makes the receiver dark cyan.
	def dark_cyan; colorize(self, "\e[0;36m"); end

	# Uncolorizes string.
	def uncolorize;	self.gsub!(/\e\[\d[;0-9]*m/, '') end

	# Colorizes the receiver according the given ASCII escape character sequence.
	# Thanks to: http://kpumuk.info/ruby-on-rails/colorizing-console-ruby-script-output/
	def colorize(text, color_code) 
		RedBook.colors ? "#{color_code}#{text}\e[0m" : text
	end
end

