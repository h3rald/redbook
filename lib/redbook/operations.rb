#!/usr/bin/env ruby

# Defining default operations

module RedBook

	operation(:log){
		target { set :required;	rewrite_as :text }
		parameter(:timestamp) { type :time }
		parameter :type 
		body { |params|
			@engine.log params
			info "Entry logged."
		}
	}

	operation_alias :insert => :log

	operation(:select){
		target { rewrite_as(:text.like){|v| "%#{v}%" }}
		parameter(:from) { type :time; rewrite_as(:timestamp.gt) }
		parameter(:to) { type :time; rewrite_as(:timestamp.lt)}
		parameter(:type)  { type :list}
		parameter(:first) { type :integer }
		parameter(:last) { type :integer }
		body { |params|
			if params.has_key? :load then
				out = RedBook.output
				RedBook.output = false
			end
			result = @engine.select params
			count = 1
			display result if RedBook.output
			info "#{result.length} item#{result.length == 1 ? '' : 's'} loaded into dataset."
			RedBook.output = out if params.has_key? :load
		}
	}

	operation_alias :load => :select	

	operation(:update){
		target { set :required; type :integer }
		parameter :text
		parameter(:timestamp) { type :time }
		parameter :type
		body { |params|
			@engine.update params.delete(:update), params
			info "Item ##{params[0]} updated successfully."
		}
	}

	operation(:delete) do
		target { type :intlist }
		body { |params|
			msg = ""
			case
			when params[:delete].blank? then
				msg = "the whole dataset"
			when params[:delete].length == 1 then
				msg = "this item"
			else
				msg = "these items"
			end	
			if confirm(" >> Do you really want to delete #{msg}? ") then
				@engine.delete params[:delete]
				info "Operation successful."
			else
				warning "Nothing to do."
			end
		}
	end

	operation(:save){
		target { set :required }
		parameter(:format) { set :required; rewrite_as(:format){|v| v.to_sym} }
		body { |params|
			@engine.save params[:save], params[:format]
			info "Dataset saved to '#{params[:save]}'"
		}
	}

	operation(:ruby){
		target { set :required }
		body { |params|
			result = nil
			begin 
				result = @engine.ruby params[:ruby]
			rescue Exception => e
				raise UIError, e.message, e.backtrace
			end
			result.to_s.each_line { |l| puts " #{l}" if RedBook.output }
		}
	}

	operation(:rename){		
		target { set :required }
		parameter(:from) { set :required }
		parameter(:to) { set :required }
		body { |params|
			@engine.rename params[:rename], params[:from], params[:to]
			info "#{params[:rename].to_s.camelize} '#{params[:from]}' renamed to '#{params[:to]}'."
		}
	}

	operation(:cleanup){
		target { type :list }
		body { |params|
			info "Cleaning up unused records..."
			@engine.cleanup params[:cleanup]
			info "Cleanup complete."
		}
	}

	operation(:refresh){
		target { type :list }
		body { |params|
			@engine.refresh params[:inventory]
			info "Inventory loaded."
		}
	}

	operation(:use){
		target { set :required }
		body { |params|
			file = RedBook.config.repositories[params[:use].to_sym] if params[:use]
			@engine = RedBook::Engine.new file
			if file then
				info "Switched to repository '#{name}' [#{file}]."
			else
				warning "Unknown repository, switched to default one."
			end			
		}
	}

	operation(:quit) {
		body{ |params|
			debug "Stopping RedBook CLI..."
			exit
		}
	}

	operation(:debug) {
		body { |params|
			@engine.debug
			info "Debug #{RedBook.debug ? 'on' : 'off'}."
		}
	}

	operation(:output) {
		body { |params|
			@engine.output		
			info "Output #{RedBook.output ? 'on' : 'off'}."
		}
	}

	operation(:color) {
		body { |params|
			RedBook.colors = RedBook.colors ? false : true
			info "Colors #{RedBook.colors ? 'on' : 'off'}."
		}
	}

	operation(:dataset) {
		body { |params|
			if @engine.dataset.blank? then
				warning "Empty dataset."
				return
			end
			display @dataset if RedBook.output
		}
	}
	operation(:clear) {
		body { |params|
			system(RUBY_PLATFORM.match(/win/i) ? "cls" : "clear")
		}
	}

end
