#!/usr/bin/env ruby

module RedBook

	class Parser

		class Operation
			attr_accessor :parameters, :name, :alias

			def to_s
				@name.to_s
			end

			def to_str
				@name.to_s
			end

			def initialize(name)
				@name = name
				@parameters = {}
				@alias = nil
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
			include Hookable
			attr_accessor :name, :parameter_type, :required, :values, :special, :rewrite

			def to_s
				@name.to_s
			end

			def to_str
				@name.to_s
			end

			def initialize(name)
				@name = name
				@parameter_type = :string
				@required = false
				@special = nil
				@values = []
				yield self if block_given?
			end

			def rewrite_as(key, &block)
				@rewrite = key
				@rewrite_block = block if block_given?
			end

			def rewrite_value(params)
				if params.has_key? @name then
					if @rewrite_block
						params[@rewrite] =@rewrite_block.call(params[@name])
					else
						params[@rewrite] = params[@name]
					end
					params.delete @name unless @name == @rewrite
				end
			end

			def parse(value="")
				if value.blank? then
					raise ParserError, "Please specify a value for the ':#{self}' directive." if @required
					return nil
				end
				case @parameter_type
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
					raise ParserError, "Unknown parameter type '#{@parameter_type.textualize}' for parameter ':#{self}'." unless return_value
					return return_value
				end
			end
		end

		# Parser Class

		include Hookable
		include Messaging

		class_instance_variable :operations => {}
		class_instance_variable :macros => {}
		class_instance_variable :time_context => :past
		class_instance_variable :now => nil

		def self.macro(name, str)
			self.macros[name] = str
		end

		def self.operation(name, &block)
			self.operations[name] = Operation.new(name, &block)
		end

		def self.alias_operation(pair)
			raise ParserError, "Alias operation must be specified using a pair ':alias => :original'" unless pair.is_a?(Hash) && pair.pair?
			old_op = pair.value
			new_op = pair.name
			_old = self.operations[old_op]
			_new = self.operation new_op 
			_new.parameters = _old.parameters
			_new.parameters[new_op] = _old.parameters[old_op]
			_new.alias = old_op
		end

		def parse(str)
			directives = parse_ruby_code(parse_command(str))
			operation = Parser.operations[directives[0].to_sym]
			return parse(parse_macro(str, directives)) if operation.blank?		
			parameters = parse_parameters operation, directives
			check_required_parameters operation, parameters
			operation.parameters.each_value { |v| v.rewrite_value(parameters) if v.rewrite }
			parameters = nil if parameters.blank?
			debug "Parsed operation '#{operation.name}'"
			return operation.name, parameters
		end

		private

		def parse_macro(str, directives)
			name = directives[0]
			macro = Parser.macros[name.to_sym]
			raise ParserError, "Unknown operation '#{name}'." unless macro	
			placeholders = macro.scan(/<([a-z_]+)>/).to_a.flatten
			raw_params = {}
			result = macro.dup
			i = 0
			while i < directives.length do
				key = directives[i].gsub(/^-/, '').to_sym
				value = directives[i+1]
				if placeholders.include? key.to_s then
					raw_params[key] = value
				else
					result << " -#{key} #{value}"
				end				
				i = i+2
			end
			# Substitute placeholders
			raw_params.each_pair do |label, value|
				result.gsub!(/<#{label}>/, value)
			end
			debug "Processed macro: '#{result}'"
			return result
		end

		def parse_ruby_code(directives)
			regex = /%=(.+?)=%/
				directives.tap do |ds|
				ds.each do |v|
					v.scan(regex).to_a.flatten.else(:blank?).each do |c|
						begin
							Kernel.instance_eval(c).tap { |e|	v.sub! regex, e.to_s }
						rescue
							raise ParserError, "Error evaluating '#{c}'."
						end
					end
					end
				end
		end

		def parse_command(str)
			str.split(/(^[a-z_]+){1}|(\s-[a-z_]+){1}/).tap do |directives|
				directives.delete_at(0)
				raise ParserError, "No operation specified." if directives.blank?
				directives.each { |d| d.strip! }
			end
		end

		def parse_parameters(operation, directives)
			{}.tap do |parameters|
				i = 0
				while i < directives.length do
					key = directives[i].gsub(/^-/, '').to_sym
					value = directives[i+1]
					unless operation.parameters[key] # Unknown parameters are ignored
						i = i+2
						next
					end
					parameters[key] = operation.parameters[key].parse value
					# Alias support
					if operation.alias && key == operation.name then
						parameters[operation.alias] = parameters[key] 
						parameters.delete operation.name
					end
					i = i+2
				end
			end
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
		o.parameter(:log) { |p| p.required = true; p.rewrite_as :text }
		o.parameter(:timestamp) { |p| p.parameter_type = :time }
		o.parameter :type 
	end

	alias_operation :insert => :log

	operation(:relog) do |o|
		o.parameter(:log) { |p| p.required = true, p.parameter_type = :integer}
		o.parameter :as
	end

	operation(:select) do |o|
		o.parameter(:select) { |p| p.rewrite_as(:text.like){|v| "%#{v}%" }}
		o.parameter(:from) { |p| p.parameter_type = :time; p.rewrite_as(:timestamp.gt) }
		o.parameter(:to) { |p| p.parameter_type = :time; p.rewrite_as(:timestamp.lt)}
		o.parameter(:type)  { |p| p.parameter_type = :list}
		o.parameter(:first) { |p| p.parameter_type = :integer }
		o.parameter(:last) { |p| p.parameter_type = :integer }
	end

	alias_operation :load => :select

	operation(:update) do |o|
		o.parameter(:update) { |p| p.required = true; p.parameter_type = :integer }
		o.parameter :text
		o.parameter(:timestamp) { |p| p.parameter_type = :time }
		o.parameter :type
	end

	operation(:delete) do |o|
		o.parameter(:delete) { |p| p.parameter_type = :intlist }
	end

	operation(:save) do |o|
		o.parameter(:save) { |p| p.required = true }
		o.parameter(:format) { |p| p.required = true; p.rewrite_as(:format){|v| v.to_sym} }
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
		o.parameter(:cleanup) { |p| p.parameter_type = :list }
	end

	operation(:refresh) do |o|
		o.parameter(:refresh) { |p| p.parameter_type = :list }
	end

	operation(:detail) do |o|
		o.parameter(:detail) { |p| p.parameter_type = :intlist }
	end

	operation(:use) do |o|
		o.parameter :use
	end

	operation :quit
	operation :debug
	operation :output
	operation :color
	operation :dataset
	operation :clear
end
