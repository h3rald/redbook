#!/usr/bin/env ruby

module RedBook
	class Cli

		include Messaging
		include Hookable

		attr_reader :engine, :editor

		def initialize(repository=nil, prompt=" >> ")
			@prompt = prompt
			@parser = Parser.new
			@emitter = Emitter.new('cli', true)
			@engine = Engine.new(repository)
			[@parser, @engine, self].each { |o|	o.add_observer self }
			RedBook::PluginCollection.plugins.each_pair { |l, v| v.add_observer self; v.init }
			@editor = RawLine::Editor.new
			setup_completion
			setup_shortcuts
			@engine.refresh
		end

		def start
			info "RedBook CLI started."
			# Main REPL
			loop do
				begin
					process @editor.read(@prompt)
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
			raise CliError, "Operation '#{operation.to_sym.textualize}' is not accessible from this shell." unless respond_to? name
			m = method(name)
			(params.blank?) ? m.call : m.call(params)
		end

		def update(message)
			display :message, :message => message
		end

		def display(symbol, params)
			puts @emitter.render(symbol, params).chomp
		end

		def setup_completion
			operations = []
			RedBook::Parser.operations.each_pair do |l,v|
				operations << ":#{l.to_s}"
			end
			RedBook::Parser.macros.each_pair do |l,v|
				operations << ":#{l.to_s}"
			end
			@editor.completion_proc = lambda do |str|
				if @editor.line.text.strip == str.strip then
					return operations.find_all { |e| e.to_s.match(/^#{Regexp.escape(str)}/) }
				else
					matches = []
					words = @editor.line.words
					name = words[0].symbolize
					add_operation_params = lambda do |name, matches|
						operation = RedBook::Parser.operations[name]
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
						macro = RedBook::Parser.macros[name]
						if macro then
							macro_params = macro.scan(/:([a-z_]+)/).to_a.flatten
							macro_params.each { |p| matches << p unless @editor.line.text.match p}
							add_operation_params.call macro_params[0].to_sym, matches
							# Remove original operation from parameters
							matches.delete(macro_params[0].symbolize.textualize)
						end
					end
					if @editor.line.text.match /:rename\s[a-z]+$/ then
						RedBook.inventory_tables.each { |t| matches << t.to_s }
					end
					hook :setup_completion, :cli => self, :matches => matches
					return matches.find_all { |e| e.to_s.match(/^#{Regexp.escape(str)}/) }
				end
			end
		end

		def setup_shortcuts
			shortcut "\e\e", ":quit"
			hook :cli_shortcuts, :cli => self
		end

		def shortcut(seq, command)
			@editor.bind(seq) { @editor.write_line command }
		end

		### Operations

		def quit_operation
			debug "Stopping RedBook CLI..."
			exit
		end

		def debug_operation
			@engine.debug
			info "Debug #{RedBook.debug ? 'on' : 'off'}."
		end

		def output_operation
			@engine.output		
			info "Output #{RedBook.output ? 'on' : 'off'}."
		end

		def log_operation(params)
			@engine.log params
			info "Entry logged."
		end

		def select_operation(params=nil)
			result = @engine.select params
			count = 1
			result.each do |e| 
				display :entry, :entry => e, :index => count if RedBook.output
				count = count+1
			end
			info "#{result.length} item#{result.length == 1 ? '' : 's'} loaded into dataset."
		end

		def update_operation(params)
			indexes = params.delete :update
			@engine.update indexes, params
			info "Item #{params[0].to_s} updated successfully."
		end

		def delete_operation(params=nil)
			msg = ""
			case
			when params[:delete].blank? then
				msg = "the whole dataset"
			when params[:delete].length == 1 then
				msg = "this item"
			else
				msg = "these items"
			end	
			if agree(" >> Do you really want to delete #{msg}? ") then
				@engine.delete params[:delete]
				info "Operation successful."
			else
				warning "Nothing to do."
			end
		end

		def dataset_operation
			if @engine.dataset.blank? then
				warning "Empty dataset."
				return
			end
			count = 1
			@engine.dataset.each do |i|
				display :entry, :entry => i, :index => count if RedBook.output
				count +=1
			end
		end

		def ruby_operation(string)
			result = nil
			begin 
				result = @engine.ruby string
			rescue Exception => e
				raise CliError, e.message, e.backtrace
			end
			result.to_s.each_line { |l| puts " #{l}" if RedBook.output }
		end	

		def save_operation(params)
			@engine.save params[:save], params[:format]
			info "Dataset saved to '#{params[0]}'"
		end

		def rename_operation(params)
			@engine.rename params[:rename], params[:from], params[:to]
			info "#{params[:rename].to_s.camelize} '#{params[:from]}' renamed to '#{params[:to]}'."
		end

		def cleanup_operation(params=nil)
			info "Cleaning up unused records..."
			@engine.cleanup params[:cleanup]
			info "Cleanup complete."
		end

		def refresh_operation(params=nil)
			@engine.refresh params[:inventory]
			info "Inventory loaded."
		end	
	end
end
