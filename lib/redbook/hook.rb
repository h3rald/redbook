#!/usr/bin/env ruby

module RedBook

	# The Hook class is used by the Hookable module to wrap
	# a Proc object which is executed within
	# a method of a hookable class (do not use directly).
	class Hook

		# Defines a new hook.
		def initialize(id, &block)
			block_given? ? @block = block :	raise(ArgumentError, "No action specified for '#{id.to_s}' hook")
			@id = id
		end

		# Executes the hook. The hook process should return a hash:
		# {:value => (hook result), :stop => (stop processing hooks)}
		def execute(params={})
			@block.call(params).then([:is_a?, Hash]).else{raise EngineError, "Invalid hook definition (hash not returned)."}
		end

	end

	# A collection of Hook objects to be executed sequentially
	# within a method of a class including the
	# Hookable module (do not use directly).
	class HookCollection

		def initialize
			@contents = {}
		end

		def [](id)
			@contents[id]
		end

		def []=(id, value)
			@contents[id] = value
		end

		# Execute the hooks labeled with +id+ sequentially.
		def execute(id, params={})
			return nil unless self[id]
			result = nil
			@contents[id].each do |c|
				result = c.execute(params)
				break if result[:stop] == true
			end
			result[:value]
		end

	end

	# The Hookable module is used to add hooking capabilities to a class.
	#
	# <i>Usage</i>
	#
	# <tt># Creating a new hookable class</tt>
	#
	# <tt>class MyClass</tt>
	# 	include Hookable
	#
	# 	def method_with_hooks
	# 		hook :before_something, :arg1 => 20
	# 		# Method logic goes here
	# 	end
	# <tt>end</tt>
	#
	#	# Defining a :before_something hook for MyClass.
	# <tt>MyClass.define_hook :before_something do</tt>
	# 	# Hook logic goes here
	# <tt>end</tt>
	module Hookable

		def self.included(mod)
			mod.instance_eval do
				class_instance_variable :hooks => HookCollection.new

				# Defines a new hook for the hookable class.
				def define_hook(id, &block)
					h = Hook.new id, &block
					@hooks[id] = [] unless @hooks[id]
					@hooks[id] << h
				end

				# Continue hook execution.
				def continue(value=nil)
					{:value => value, :stop => false}
				end

				# Stop hook execution.
				def stop(value=nil)
					{:value => value, :stop => true}
				end

				# If result is true, then continue(true), else stop(false)
				def stop_hooks_unless(result)
					(result == true) ? continue(true) : stop(false)
				end
			end

			# Triggers the execution of a particular hook at instance level.
			def hook(id, params={})
				self.class.hooks.execute id, params
			end
		end

	end
end


