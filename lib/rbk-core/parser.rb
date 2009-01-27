#!/usr/bin/env ruby

module RedBook

	class Parser

		class Operation

			attr_accessor :params, :name, :post_parsing

			def initialize(name)
				@name = name
				@params = {}
				@post_parsing = nil
				yield self if block_given?
			end

			def parameter(name, &block)
				@params[name] = Parameter.new(name, &block)
			end
		end

		def to_s
			":"+name.to_s
		end

		alias to_str to_s

		class Parameter 

			attr_accessor :name, :type, :required

			def to_s
				":"+name.to_s
			end

			alias to_str to_s

			def initialize(name)
				@name = name
				@type = :string
				@required = false
				yield self if block_given?
			end

			def parse(value="")
				raise ParserError, "A value for ':#{@name.to_s}' is required." if value.blank? && @required
				case @type
				when :string then
					return value
				when :time then
					now = Parser.now || Time.now
					begin
						result = Chronic.parse(value, :context => Parser.time_context, :now => now)
						raise ParserError, "Parameter ':#{@name.to_s}' is not a time expression." unless result.class == Time
						return result
					rescue
						raise ParserError, "Parameter ':#{@name.to_s}' is not a time expression."
					end
				when :integer then
					begin
						result = value.to_i
						raise ParserError, "Parameter ':#{@name.to_s}' is not an integer." if result == 0 && value != "0"
						return result
					rescue
						raise ParserError, "Parameter ':#{@name.to_s}' is not an integer."
					end	
				when :float then
					begin 
						result = value.to_f
						raise ParserError, "Parameter ':#{@name.to_s}' is not a float." if result == 0.0 && value != "0.0"
						return result
					rescue
						raise ParserError, "Parameter ':#{@name.to_s}' is not a float."
					end	
				when :list then
					raise ParserError, "Parameter ':#{@name.to_s}' is not a list." if value.blank?
					return value.strip.split(' ')
				when :bool then 
					return true 
				else
					return_value = nil
					hook :parse_custom_type, :value => value, :return => return_value
					raise ParserError, "Unknown type ':#{@type.to_s}' for parameter ':#{@name.to_s}'." unless return_value
					return return_value
				end
			end
		end

		# Parser Class

		include Hookable
		include Messaging

		class << self; attr_accessor :operations, :time_context, :now; end

		@now = nil
		@time_context = :past
		@operations = {}

		def self.operation(name, &block)
			self.operations[name] = Operation.new(name, &block)
		end

		def parse(str)
			directives = str.split(/(^:[a-z_]+){1}|(\s+:[a-z_]+){1}/)
			directives.delete_at(0)
			raise ParserError, "No operation specified." if directives.blank?
			directives.each { |d| d.strip! }
			operation = Parser.operations[instance_eval(directives[0])]
			raise ParserError, "Unrecognized operation '#{directives[0]}'." unless operation
			parameters = {}
			i = 0
			while i < directives.length do
				key = instance_eval directives[i]
				value = directives[i+1]
				unless operation.params[key] # Unknown parameters are ignored
					i = i+2
					next
				end
				parameters[key] = operation.params[key].parse value
				i = i+2
			end
			parameters = operation.post_parsing.call parameters if operation.post_parsing
			parameters = nil if parameters.blank?
			debug "Parameters for operation #{operation.to_s}:"
			debug parameters.to_yaml
			return operation.name, parameters
		end

	end
end

# Defining default operations

class RedBook::Parser

	operation(:log) do |o|
		o.parameter(:log) { |p| p.required = true }
		o.parameter(:timestamp) { |p| p.type = :time }
		o.parameter :type
		o.post_parsing = lambda do |params|
			params[:text] = params[:log]
			params.delete(:log)
			return params
		end
	end

	operation(:select) do |o|
		o.parameter :select
		o.parameter(:from) { |p| p.type = :time }
		o.parameter(:to) { |p| p.type = :time }
		o.parameter :type  
		o.post_parsing = lambda do |params|
			result = {}
			result[:timestamp.lt] = params[:to] unless params[:to].blank?
			result[:timestamp.gt] = params[:from] unless params[:from].blank?
			result[:text.like] = "%#{params[:select]}%" unless params[:select].blank?
			result[:type] = params[:type] unless params[:type].blank?
			params.delete(:select)
			params.delete(:from)
			params.delete(:to)
			params.delete(:type)
			params.merge! result
			return params
		end	
	end

	operation(:update) do |o|
		o.parameter(:update) { |p| p.required = true; p.type = :integer }
		o.parameter :text
		o.parameter(:timestamp) { |p| p.type = :time }
		o.parameter :type
		o.post_parsing = lambda do |params|
			return params.delete(:update), params
		end
	end

	operation(:delete) do |o|
		o.parameter(:delete) { |p| p.required = true; p.type = :integer }
		o.post_parsing = lambda do |params|
			return params[:delete]
		end
	end

	operation(:save) do |o|
		o.parameter(:save) { |p| p.required = true }
		o.parameter :format
		o.post_parsing = lambda do |params|
			return params[:save], params[:format].to_sym
		end
	end

	operation :quit
	operation :debug
	operation :output
	operation :dataset

	operation(:ruby) do |o|
		o.parameter(:ruby) { |p| p.required = true }
		o.post_parsing = lambda do |params|
			return params[:ruby]
		end
	end

end
