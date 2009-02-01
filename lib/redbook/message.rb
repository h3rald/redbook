#!/usr/bin/env ruby

module RedBook
	class Message

		attr_accessor :children, :attributes, :parent, :name, :value

		def initialize(name, value)
			raise TypeError, "Name is not a Symbol" unless name.is_a? Symbol
			raise TypeError, "Value must not be a message" if value.is_a? RedBook::Message
			@name = name
			@value = value
			@children = []
			@attributes = {}
			@parent = nil
		end

		def <<(child)
			raise TypeError, "Object is not a message" unless child.is_a? RedBook::Message
			child.parent = self
			@children << child
		end

		def <=(attributes)
			raise TypeError, "Object is not a Hash" unless attributes.is_a? Hash
			@attributes.merge! attributes
		end

		def /(sym)
			r = []
			@children.each do |c|
				if c.name == sym
					r << c
				end
			end
			return r 
		end

		def [](label)
			@attributes[label]
		end

		def recurse(&block)
			yield(self)
			@children.each { |c| c.recurse(&block) } unless @children.empty?
		end
	end

	module Messaging
		
		include Observable
		
		def info(message)
			notify(:info, message) if RedBook.output
		end

		def warning(message)
			notify(:warning, message) if RedBook.output
		end
		
		def error(message)
			notify(:error, message)
		end

		def debug(message)
			notify(:debug, message) if RedBook.debug
		end

		def notify(name, value)
			changed
			notify_observers msg(name, value) 
			msg(name, value)
		end
		
	end

end

module Kernel

	def msg(name, value)
		RedBook::Message.new(name, value)
	end

end
