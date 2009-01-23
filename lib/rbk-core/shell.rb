#!/usr/bin/env ruby

module RedBook
	class Shell

		include Messaging

		def initialize(repository=nil, prompt=">> ")
			@prompt = prompt
			@parser = Parser.new
			@emitter = Emitter.new('cli', true)
			@engine = Engine.new(repository)
			[@parser, @engine, self].each do |o|
				o.add_observer self
			end
		end
		
		def start
			info "RedBook Shell started."
			# Main REPL
			loop do
				begin
					print @prompt
					operation, params = @parser.parse gets
					name = (operation.to_s+"_operation").to_sym
					raise ShellError, "Operation ':#{operation.to_s}' is not accessible via this shell." unless respond_to? name
					m = method(name)
					(params.blank?) ? m.call : m.call(params)
				rescue Exception => e
					if e.class == SystemExit || e.class == Interrupt then
						warning "RedBook Shell stopped."
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
			puts @emitter.render(:message, :message => message)
		end

		# Operations
		
		def quit_operation
			debug "Stopping RedBook Shell..."
			exit
		end

		def debug_operation
			RedBook.debug = !RedBook.debug
			info "Debug #{RedBook.debug ? 'on' : 'off'}."
		end

		def output_operation
			if RedBook.output then
				info "Output off."
				RedBook.output = false
			else
				RedBook.output = true
				info "Output on."
			end
		end

	end
end
