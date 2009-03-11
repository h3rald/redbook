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
			raise CliError, "Operation '#{operation.to_sym.textualize}' is not accessible from this shell." unless respond_to? name
			self.send name, params
		end

		def update(message)
			display message
		end

		def display(object)
			puts @emitter.render(object).chomp
		end

		def setup_completion
			operations = []
			op_prefix = RedBook.config.parser.operation_prefix || ':'
			ph_prefix = RedBook.config.parser.placeholder_prefix || ':'
			param_prefix = RedBook.config.parser.parameter_prefix || ':'
			RedBook::Parser.operations.each_pair do |l,v|
				operations << "#{op_prefix}#{l.to_s}"
			end
			RedBook::Parser.macros.each_pair do |l,v|
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

		### Operations

		def use_operation(params=nil)
  		if params[:use] then
				name = params[:use].to_sym
				file = RedBook.config.repositories[name]
			end
			@engine = RedBook::Engine.new file
			if file then
				info "Switched to repository '#{name}' [#{file}]."
			else
				warning "Unknown repository, switching to default one."
			end			
		end

		def detail_operation(params)
			raise CliError, "Empty dataset." if @engine.dataset.blank?
			result = []
			count = 0
			unless params[:detail].blank?
				params[:detail].each { |i| result << @engine.dataset[i-1] }
			else
				result = @engine.dataset
			end
			display result, :details => true if RedBook.output 
		end

		def clear_operation(params=nil)
			command = RUBY_PLATFORM.match(/win/i) ? "cls" : "clear"
			system command
		end

		def quit_operation(params=nil)
			debug "Stopping RedBook CLI..."
			exit
		end

		def debug_operation(params=nil)
			@engine.debug
			info "Debug #{RedBook.debug ? 'on' : 'off'}."
		end

		def output_operation(params=nil)
			@engine.output		
			info "Output #{RedBook.output ? 'on' : 'off'}."
		end

		def color_operation(params=nil)
			RedBook.colors = RedBook.colors ? false : true
			info "Colors #{RedBook.colors ? 'on' : 'off'}."
		end

		def log_operation(params)
			@engine.log params
			info "Entry logged."
		end

		alias insert_operation log_operation

		def relog_operation(params)
			@engine.log params[:relog], params[:as]
			info "Entry relogged."
		end

		def select_operation(params=nil)
			result = @engine.select params
			count = 1
			display result if RedBook.output
			info "#{result.length} item#{result.length == 1 ? '' : 's'} loaded into dataset."
		end

		def load_operation(params=nil)
			out = RedBook.output
			RedBook.output = false
			select_operation(params)
			RedBook.output = out
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

		def dataset_operation(params=nil)
			if @engine.dataset.blank? then
				warning "Empty dataset."
				return
			end
			display @dataset if RedBook.output
		end

		def ruby_operation(params)
			result = nil
			begin 
				result = @engine.ruby params[:ruby]
			rescue Exception => e
				raise CliError, e.message, e.backtrace
			end
			result.to_s.each_line { |l| puts " #{l}" if RedBook.output }
		end	

		def save_operation(params)
			@engine.save params[:save], params[:format]
			info "Dataset saved to '#{params[:save]}'"
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
