#!/usr/bin/env ruby

module RedBook
	class Emitter

		attr_accessor :templates

		@@template_dirs = []

		def self.template_dirs
			@@template_dirs
		end

		def initialize(format, cache=false)
			@cache = cache
			@format = format
			set_folder = lambda do |folder|
				begin 
					Dir.new(folder)
				rescue
					nil
				end
			end
			@@template_dirs << CORE_DIR/'../templates' unless @@template_dirs.include? CORE_DIR/'../templates'
			@templates = {}
			if @cache then
				@@template_dirs.each {|d| load_templates d}
			end
		end
			
		def render(template, params={})
			load_template template unless @templates[template]
			begin
				return @templates[template].evaluate(params)
			rescue
				raise EmitterError, "Unable to render template '#{template.to_s}'"
			end
			nil
		end

		def load_templates(dir)
			Dir.glob(dir/"*.erb").each do	|f| 
				load_template(:"#{File.basename(f, ".#{@format.to_s}.erb")}") if f =~ /#{@format.to_s}\.erb$/ 
			end
		end

		def load_template(template)
			name = "#{template.to_s}.#{@format.to_s}.erb"
			file = nil
			@@template_dirs.each do |d|
				file = d/name if File.exists? d/name
			end
			raise EmitterError, "Template '#{template.to_s}.#{@format.to_s}' not found." unless file
			@templates[template] = Erubis::TinyEruby.new(File.read(file))
		end

	end
end
