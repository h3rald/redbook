#!/usr/bin/env ruby

module RedBook

	class Parser

		class Operation
			attr_accessor :parameters, :name, :post_parsing

			def to_s
				@name.to_s
			end

			def to_str
				@name.to_s
			end

			def initialize(name)
				@name = name
				@parameters = {}
				@post_parsing = []
				yield self if block_given?
			end

			def parameter(name, &block)
				@parameters[name] = Parameter.new(name, &block)
			end
			
			def modify
				yield self if block_given?
			end
		end


		class Parameter 
			attr_accessor :name, :type, :required, :values

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
				@values = []
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
					return [] if value.blank?
					return value.strip.split
				when :intlist then
					result = []
					return result if value.blank?
					intlist = value.strip.split
					intlist.each do |i|
						item = i.to_i
						raise ParserError, "Parameter ':#{self}' is not a list of integers." if item == 0 && i != "0"
						result << item
					end
					return result
				when :enum
					raise ParserError, "Parameter':#{self}' must be set to one of the following values: #{@values.join(', ')}" unless @values.include? value.strip
					return value.strip
				when :bool then 
					return true if value.match(/yes|on|true/i)
					return false	
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

		class << self; attr_accessor :operations, :macros, :time_context, :now, :special_attributes; end

		@now = nil
		@time_context = :past
		@operations = {}
		@macros = {}
		@special_attributes = []

		def self.macro(name, str)
			self.macros[name] = str
		end

		def self.operation(name, &block)
			self.operations[name] = Operation.new(name, &block)
		end

		def parse(str)
			directives = parse_command str
			operation = Parser.operations[directives[0].symbolize]
			return parse(parse_macro(str, directives)) if operation.blank?		
			parameters = parse_directives operation, directives
			check_required_parameters operation, parameters
			operation.post_parsing.each{ |p| p.call parameters }
			parameters = nil if parameters.blank?
			return operation.name, parameters
		end
	
		private

		def parse_macro(str, directives)
			name = directives[0]
			macro = Parser.macros[name.symbolize]
			raise ParserError, "Unknown operation '#{name}'." unless macro	
			placeholders = macro.scan(/<:([a-z_]+)>/).to_a.flatten
			raw_params = {}
			result = macro.dup
			i = 0
			while i < directives.length do
				key = directives[i].symbolize
				value = directives[i+1]
				if placeholders.include? key.to_s then
					raw_params[key] = value
				else
					result << ' '+key.textualize+' '+value
				end				
				i = i+2
			end
			# Substitute placeholders
			raw_params.each_pair do |label, value|
				result.gsub!(/<#{label.textualize}>/, value)
			end
			debug "Processed macro: '#{result}'"
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
				key = directives[i].symbolize
				value = directives[i+1]
				unless operation.parameters[key] # Unknown parameters are ignored
					i = i+2
					next
				end
				parameters[key] = operation.parameters[key].parse value
				i = i+2
			end
			parameters
		end


		def check_required_parameters(operation, parameters)
			operation.parameters.each_pair do |label, p|
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
		o.post_parsing << lambda do |params|
			params[:text] = params[:log]
			params.delete(:log)
		end
	end

	operation(:select) do |o|
		o.parameter :select
		o.parameter(:from) { |p| p.type = :time }
		o.parameter(:to) { |p| p.type = :time }
		o.parameter(:type)  { |p| p.type = :list}
		o.parameter(:first) { |p| p.type = :integer }
		o.parameter(:last) { |p| p.type = :integer }
		o.post_parsing << lambda do |params|
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
		end	
	end

	operation(:update) do |o|
		o.parameter(:update) { |p| p.required = true; p.type = :integer }
		o.parameter :text
		o.parameter(:timestamp) { |p| p.type = :time }
		o.parameter :type
	end

	operation(:delete) do |o|
		o.parameter(:delete) { |p| p.type = :intlist }
	end

	operation(:save) do |o|
		o.parameter(:save) { |p| p.required = true }
		o.parameter(:format) { |p| p.required = true }
		o.post_parsing << lambda do |params|
			params[:format] = params[:format].to_sym
		end
	end

	operation(:ruby) do |o|
		o.parameter(:ruby) { |p| p.required = true }
	end

	operation(:rename) do |o|
		o.parameter(:rename) { |p| p.required = true }
		o.parameter(:from) { |p| p.required = true }
		o.parameter(:to) { |p| p.required = true }
	end

	operation(:cleanup) do |o|
		o.parameter(:cleanup) { |p| p.type = :list }
	end

	operation(:refresh) do |o|
		o.parameter(:refresh) { |p| p.type = :list }
	end

	operation(:detail) do |o|
		o.parameter(:detail) { |p| p.type = :intlist }
	end

	operation :quit
	operation :debug
	operation :output
	operation :dataset
	operation :clear

	macro :entries, ":select <:entries> :type entry"

end
