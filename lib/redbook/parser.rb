#!/usr/bin/env ruby

module RedBook

	class Parser

		class Operation
			attr_accessor :params, :name, :post_parsing

			def to_s
				@name.to_s
			end

			def to_str
				@name.to_s
			end

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


		class Parameter 
			attr_accessor :name, :type, :required

			def to_s
				@name.to_s
			end

			def to_str
				@name.to_s
			end

			def initialize(name)
				@name = name
				@type = :string
				@required = false
				yield self if block_given?
			end

			def parse(value="")
				raise ParserError, "Please specify a value for the ':#{self}' directive." if value.blank? && @required
				case @type
				when :string then
					return value
				when :time then
					now = Parser.now || Time.now
					begin
						result = Chronic.parse(value, :context => Parser.time_context, :now => now)
						raise ParserError, "Parameter ':#{self}' is not a time expression." unless result.class == Time
						return result
					rescue
						raise ParserError, "Parameter ':#{self}' is not a time expression."
					end
				when :integer then
					begin
						result = value.to_i
						raise ParserError, "Parameter ':#{self}' is not an integer." if result == 0 && value != "0"
						return result
					rescue
						raise ParserError, "Parameter ':#{self}' is not an integer."
					end	
				when :float then
					begin 
						result = value.to_f
						raise ParserError, "Parameter ':#{self}' is not a float." if result == 0.0 && value != "0.0"
						return result
					rescue
						raise ParserError, "Parameter ':#{self}' is not a float."
					end	
				when :list then
					raise ParserError, "Parameter ':#{self}' is not a list." if value.blank?
					return value.strip.split(' ')
				when :bool then 
					return true 
				else
					return_value = nil
					hook :parse_custom_type, :value => value, :return => return_value
					raise ParserError, "Unknown type ':#{@type.to_s}' for parameter ':#{self}'." unless return_value
					return return_value
				end
			end
		end

		# Parser Class

		include Hookable
		include Messaging

		class << self; attr_accessor :operations, :macros, :time_context, :now; end

		@now = nil
		@time_context = :past
		@operations = {}
		@macros = {}

		def self.operation(name, &block)
			self.operations[name] = Operation.new(name, &block)
		end

		def parse(str)
			directives = parse_command str
			operation = Parser.operations[instance_eval(directives[0])]
			return parse(parse_macro(str, directives)) if operation.blank?		
			parameters = parse_directives operation, directives
			check_required_parameters operation, parameters
			parameters = operation.post_parsing.call parameters if operation.post_parsing
			parameters = nil if parameters.blank?
			debug "Parameters for operation '#{operation}':"
			debug parameters.to_yaml
			return operation.name, parameters
		end
		
		private

		def parse_macro(str, directives)
			name = directives[0]
			macro = Parser.macros[instance_eval(name)]
			raise ParserError, "Unknown operation/macro '#{name}'." unless macro	
			placeholders = macro.scan(/<:([a-z_]+)>/).to_a.flatten
			i = 0
			raw_params = {}
			while i < directives.length do
				key = instance_eval directives[i]
				value = directives[i+1]
				raw_params[key] = value
				i = i+2
			end
			result = macro.dup
			placeholders.each do |p|
				subst = raw_params[p.to_sym] ? raw_params[p.to_sym] : ''
				result.gsub!(/<:#{p}>/, subst)
			end
			return result
		end

		def parse_command(str)
			directives = str.split(/(^:[a-z_]+){1}|(\s+:[a-z_]+){1}/)
			directives.delete_at(0)
			raise ParserError, "No operation specified." if directives.blank?
			directives.each { |d| d.strip! }
			directives
		end

		def parse_directives(operation, directives)
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
			parameters
		end


		def check_required_parameters(operation, parameters)
			operation.params.each_pair do |label, p|
				# operation's target is already checked when parsed as parameter
				if p.required && label != operation.name then
					raise ParserError, "Parameter '#{p}' is required." if parameters[p.name].blank?
				end
			end
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
		o.parameter(:format) { |p| p.required = true }
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
