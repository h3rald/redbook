#!/usr/bin/env ruby

module RedBook

	class Hook

		attr_accessor :class, :id, :params, :block, :stop

		def initialize(klass, id, stop=false,&block)
			block_given? ? @block = block :	raise(ArgumentError, "No action specified for '#{id.to_s}' hook")
			@class = klass
			@id = id
			@stop = stop
			@class.hooks[id] = [] unless @class.hooks[id]
			@class.hooks[id] << self
		end

		def execute(params={})
			{:value => @block.call(params), :stop => @stop}
		end

	end

	class HookCollection < Hash

		def execute(id, params={})
			return nil unless self[id]
			result = nil
			self[id].each do |c|
				result = c.execute(params)
				break if result[:stop] == true
			end
			result[:value]
		end

	end

	module Hookable

		def self.included(mod)
			
			class << mod
				
				@@hooks = HookCollection.new
				
				def hooks
					@@hooks
				end
			
			end

		end

		def hook(id, params={})
			@@hooks.execute id, params
		end

	end
end


