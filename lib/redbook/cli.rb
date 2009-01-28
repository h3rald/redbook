#!/usr/bin/env ruby

module RedBook
	class Cli

		include Messaging

		def initialize(repository=nil, prompt=" >> ")
			@prompt = prompt
			@parser = Parser.new
			@emitter = Emitter.new('cli', true)
			@engine = Engine.new(repository)
			[@parser, @engine, self].each do |o|
				o.add_observer self
			end
		end
		
		def start
			info "RedBook CLI started."
			# Main REPL
			loop do
				begin
					print @prompt
					operation, params = @parser.parse gets
					name = (operation.to_s+"_operation").to_sym
					raise CliError, "Operation ':#{operation.to_s}' is not accessible via this shell." unless respond_to? name
					m = method(name)
					(params.blank?) ? m.call : m.call(params)
				rescue Exception => e
					if e.class == SystemExit || e.class == Interrupt then
						warning "RedBook CLI stopped."
						exit
					end
					(RedBook.debug) ? error("#{e.class.to_s}: #{e.message}") : error(e.message)
					e.backtrace.each do |m|
						debug m
					end	
				end	
			end
		end

		def update(message)
			display :message, :message => message
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
			@engine.update params[0]-1, params[1]
			info "Item #{params[0].to_s} updated successfully."
		end

		def delete_operation(index)
			if index < 1 || index > @engine.dataset.length then
				error "Invalid index."
				return
			end
			if agree(" >> Do you really want to delete item #{index.to_s}? ") then
				@engine.delete index-1
				info "Item #{index.to_s} deleted successfully."
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
			@engine.save params[0], params[1]
			info "Dataset saved to '#{params[0]}'"
		end

		### Private methods
		private

		def display(symbol, params)
			puts @emitter.render(symbol, params).chomp
		end

			
	end
end
