#!/usr/bin/env ruby

module RedBook
	class Emitter

		class CliHelper 

			def entry(e, total=1, index=0)
				timestamp = e.timestamp.textualize.dark_cyan
				text = e.text.cyan
				index =	padding(total, index)+index.to_s.cyan
				[index, timestamp, text].join ' '
			end

			def padding(total=1, index=0)
				' '*(Math.log10(total).floor-Math.log10(index).floor + 1)
			end

			def pad(num)
				' '*(Math.log10(num).floor + 2)
			end

			def message(m)
				colors = {:info => 'green', :warning => 'yellow', :error => 'red', :debug => 'magenta'}
				prefix = ">>".send :"#{colors[m.name]}"
				text = m.value.send :"dark_#{colors[m.name]}"
				"#{prefix} #{text}"
			end

			def pair(p)
				"#{(p.name.to_s.camel_case+':').dark_green} #{p.value.to_s.camel_case}"
			end
		end

		class TxtHelper < CliHelper

			def entry(e, total=1, index=0)
				super(e, total, index).uncolorize
			end

			def message(m)
				"[#{m.name}] #{m.value}"
			end
		end


		attr_accessor :templates

		class_instance_variable :template_dirs => []

		def initialize(format, cache=false)
			@cache = cache
			@format = format
			@templates = {}
			load_layout
			RedBook.config.templates.directories.each {|d| load_templates d/@format.to_s} if @cache
		end

		def render(object, args={})
			object  = (object.is_a? Hash) ? [object] : object.to_a
			count = 0
			params = {}.tap do |ps| 
				content = [].tap do |c|
					object.each do |o| 
						p = {}.tap do |h|
							h[:object] = o
							h[:total] = object.length
							h[:index] = count+=1
							h[:helper] = Emitter.const_get("#{@format}_helper".camel_case.to_sym).new rescue nil
							h[:partial] = lambda {|t| load_template(:"_#{t}.#@format").evaluate(h).chomp }
						end
						p.merge! args
						t = "#{o.resource_type}.#{@format}"
						view = load_template(t) rescue load_template("entry.#@format")
						c << view.evaluate(p).chomp
					end
				end
				ps[:content] = content.join "\n"
			end
			begin
				@templates[@format].evaluate(params).chomp
			rescue Exception => e
				raise EmitterError, "Unable to render template.", [].tap { |b| b << e.message; 	b += e.backtrace }
			end
		end

		def load_templates(dir)
			Dir.glob(dir/"*.erb").each { |f| load_template(:"#{File.basename(f, ".erb")}") if f =~ /#{@format.to_s}\.erb$/ }
		end

		def load_template(template)
			return @templates[template] if @templates[template]
			name = "#{template.to_s}.erb"
			file = nil
			RedBook.config.templates.directories.each { |d| file = d/@format.to_s/name if File.exists? d/@format.to_s/name }
			raise EmitterError, "Template '#{template.to_s}' not found." unless file
			@templates[template] = Erubis::TinyEruby.new(File.read(file))
		end

		def load_layout
			name = "#@format.erb"
			file = nil
			RedBook.config.templates.directories.each { |d| file = d/name if File.exists? d/name }
			raise EmitterError, "Template '#@format' not found." unless file
			@templates[@format] = Erubis::TinyEruby.new(File.read(file))
		end

	end
end
