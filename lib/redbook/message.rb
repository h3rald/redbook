#!/usr/bin/env ruby

module RedBook

	module Messaging
		
		include Observable
		
		def info(message)
			notify(:info, message) if RedBook.output
		end

		def warning(message)
			notify(:warning, message) if RedBook.output
		end
		
		def error(message)
			notify(:error, message)
		end

		def debug(message)
			notify(:debug, message) if RedBook.debug
		end

		def notify(name, value)
			changed
			notify_observers msg(name, value) 
			msg(name, value)
		end
	end
end


