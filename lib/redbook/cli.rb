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
						process Rawline.readline(@prompt, true)
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
			operation.exec self, params
		end

		def update(message)
			display message
		end

		def display(object, params={})
			puts @emitter.render(object, params).chomp
		end

		def confirm(msg)
			agree(msg)
		end

		def setup_completion
			operations = (RedBook.operations.keys+RedBook.macros.keys).map{|k| k.to_s}
			Rawline.completion_append_character = ' '
			Rawline.completion_proc = lambda do |str|
				if Rawline.editor.line.text.strip == str.strip then
					return operations.find_all { |e| e.to_s.match(/^#{Regexp.escape(str)}/) }
				else
					matches = []
					words = Rawline.editor.line.words
					name = words[0].to_sym
					add_operation_params = lambda do |name, matches|
						operation = RedBook.operations[name]
						if operation then
							operation.parameters.each_pair do |l,v|
								parameter = "-#{v}"
								matches << parameter unless Rawline.editor.line.text.match parameter
							end
							return true
						end
						return false
					end
					unless add_operation_params.call name, matches then  
						# Try macros
						macro = RedBook.macros[name]
						if macro then
							macro_params = macro.scan(/([a-z_]+)/).to_a.flatten
							macro_params.each { |p| matches << p unless Rawline.editor.line.text.match p}
							add_operation_params.call macro_params[0].to_sym, matches
							# Remove original operation from parameters
							matches.delete(macro_params[0])
						end
					end
					if Rawline.editor.line.text.match /rename\s[a-z]+$/ then
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
			Rawline.editor.bind(seq) do
				case 
				when command.is_a?(String) then
			 		Rawline.editor.write_line command
				when command.is_a?(Proc) then
					command.call
				end
			end
		end

	end
end
