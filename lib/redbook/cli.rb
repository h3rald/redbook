#!/usr/bin/env ruby

module RedBook
	class Cli

		include Messaging
		include Hookable

		attr_reader :engine, :editor, :parser, :emitter, :prompt

		def initialize(repository=nil, prompt=" >> ")
			@prompt = prompt
			@parser = Parser.new
			@emitter = Emitter.new('cli', true)
			@engine = Engine.new(repository)
			[@parser, @engine, self].each { |o|	o.add_observer self }
			RedBook::PluginCollection.plugins.each_pair { |l, v| v.add_observer self; v.init }
			if RedBook.config.completion then
				@editor = RawLine::Editor.new
				setup_completion
				setup_shortcuts	
			end
			@engine.refresh
		end

		def start
			info "RedBook CLI started."
			# Main REPL
			loop do
				begin
					if RedBook.config.completion then
						process @editor.read(@prompt)
					else
						print @prompt
						process gets
					end
				rescue Exception => e
					if e.class == SystemExit || e.class == Interrupt then
						info "RedBook CLI stopped."
						exit
					end
					(RedBook.debug) ? error("#{e.class.to_s}: #{e.message}") : error(e.message)
					e.backtrace.each do |m|
						debug m
					end	
				end	
			end
		end

		def process(string)
			operation, params = @parser.parse string
			name = (operation.to_s+"_operation").to_sym
			#raise CliError, "Operation '#{operation.to_sym.textualize}' is not accessible from this shell." unless respond_to? name
			####################
			if respond_to? name then
				self.send name, params
			else
				operation.exec self, params
			end	
			####################
		end

		def update(message)
			display message
		end

		def display(object)
			puts @emitter.render(object).chomp
		end

		def confirm(msg)
			agree(msg)
		end

		def setup_completion
			operations = []
			op_prefix = RedBook.config.parser.operation_prefix || ':'
			ph_prefix = RedBook.config.parser.placeholder_prefix || ':'
			param_prefix = RedBook.config.parser.parameter_prefix || ':'
			RedBook.operations.each_pair do |l,v|
				operations << "#{op_prefix}#{l.to_s}"
			end
			RedBook.macros.each_pair do |l,v|
				operations << "#{op_prefix}#{l.to_s}"
			end
			@editor.completion_proc = lambda do |str|
				if @editor.line.text.strip == str.strip then
					return operations.find_all { |e| e.to_s.match(/^#{Regexp.escape(str)}/) }
				else
					matches = []
					words = @editor.line.words
					name = words[0].symbolize
					add_operation_params = lambda do |name, matches|
						operation = RedBook.operations[name]
						if operation then
							operation.parameters.each_pair do |l,v|
								parameter = v.to_s.symbolize.textualize
								matches << parameter unless @editor.line.text.match parameter
							end
							return true
						end
						return false
					end
					unless add_operation_params.call name, matches then  
						# Try macros
						macro = RedBook.macros[name]
						if macro then
							macro_params = macro.scan(/#{op_prefix}([a-z_]+)/).to_a.flatten
							macro_params.each { |p| matches << p unless @editor.line.text.match p}
							add_operation_params.call macro_params[0].to_sym, matches
							# Remove original operation from parameters
							matches.delete(macro_params[0].symbolize.textualize)
						end
					end
					if @editor.line.text.match /#{op_prefix}rename\s[a-z]+$/ then
						RedBook.inventory_tables.each { |t| matches << t.to_s }
					end
					hook :setup_completion, :cli => self, :matches => matches
					return matches.find_all { |e| e.to_s.match(/^#{Regexp.escape(str)}/) }
				end
			end
		end

		def setup_shortcuts
			RedBook.config.cli.shortcuts.each_pair {|k,v| shortcut k, v}
		end

		def shortcut(seq, command)
			@editor.bind(seq) { @editor.write_line command }
		end
	end
end
