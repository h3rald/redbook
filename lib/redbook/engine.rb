#!/usr/bin/env ruby

module RedBook

	# The main RedBook class, used to access the repository.
	#
	# <i>Usage</i>
	#
	#	e = RedBook::Engine.new
	#	e.log :text => "an entry"
	#	e.log :text => "another entry"
	#	e.log :text => "yet another entry"
	#	e.select :text.like => "%another%" # Loads entry 2 and 3 into dataset
	#	e.update 2, :text => "An updated entry"
	#	e.delete 3
	class Engine
		
		include Hookable
		include Messaging

		attr_accessor :repository, :dataset
		
		# Sets up the repository. 
		# If +db+ is not specified, a new SQLite database is created in
		# <tt>$HOME/log.rbk</tt> (*nix, Mac) or <tt>%HOMEPATH%/log.rbk</tt>
		# (Windows).
		#
		# <i>Hooks</i>
		# * <i>:before_initialize</i> :db => String
		# * <i>:after_initialize</i> :repository => String, :dataset => Array 
		def initialize(db=nil)
			hook :before_initialize, :db => db
			db ||= "#{RedBook::HOME_DIR}/log.rbk"
			@repository = "sqlite3://#{db}"
			@dataset = []
			Repository.setup @repository
			create_repository unless File.exists? db
			hook :after_initialize, :repository => @repository, :dataset => @dataset		
		end

		# Logs an entry to the repository. 
		#
		# <i>Hooks</i>
		# * <i>:before_insert</i> :attributes => Hash
		# * <i>:after_insert</i> :attributes => Hash, :entry => RedBook::Repository::Entry
		def log(attributes={})
			hook :before_insert, :attributes => attributes
			entry = insert_entry attributes
			hook :after_insert, :attributes => attributes, :entry => entry
		end
		
		# Selects entries matching specified criteria.
		#
		# <i>Hooks</i>
		# * <i>:before_select</i> :attributes => Hash
		# * <i>:after_select</i> :attributes => Hash, :dataset => Array
		def select(attributes=nil)
			attributes = {} if attributes.blank?
			hook :before_select, :attributes => attributes
			m_debug ":select attributes:" 
			m_debug attributes.to_yaml
			@dataset = select_entries attributes
			hook :after_select, :attributes => attributes, :dataset => @dataset
			m_debug "Items in dataset: #{@dataset.length.to_s}"
			@dataset
		end

		# Updates an entry loaded into the dataset.
		#
		# <i>Hooks</i>
		# * <i>:before_update</i> :index => Integer, :attributes => Hash
		# * <i>:after_update</i> :entry => RedBook::Repository::Entry
		def update(index, attributes={})
			hook :before_update, :index => index, :attributes => attributes
			entry = update_entry index, attributes
			hook :after_update, :attributes => attributes, :entry => entry
			entry
		end

		# Deletes one or more entries loaded into the dataset.
		#
		# <i>Hooks</i>
		# * <i>:before_delete</i> :indexes => Integer
		# * <i>:before_each_delete</i> :entry => RedBook::Repository::Entry
		# * <i>:after_each_delete</i> :entry => RedBook::Repository::Entry
		# * <i>:after_delete</i>
		def delete(indexes=nil)
			hook :before_delete, :indexes => indexes
			raise EngineError "Empty dataset" if @dataset.blank?
			if indexes.blank?
				# Deletes the whole dataset
				@dataset.each { |e| delete_entry e }
			else
				indexes.each do |i| 
					entry = @dataset[i-1]
					raise EngineError "Invalid index #{i}" unless entry
					hook :before_each_delete, :entry => entry
					delete_entry entry
					hook :after_each_delete, :entry => entry
				end
			end
			hook :after_delete
		end

		# Saves the dataset's contents to a file
		#
		# <i>Hooks</i>
		# * <i>:before_save</i> :file => String, :format => Symbol
		# * <i>:after_save</i> :file => String
		# * <i>:saved_file_header</i> :format => Symbol # => String
		# * <i>:saved_file_footer</i> :format => Symbol # => String
		def save(file, format=:txt)
			raise EngineError, "Empty dataset." if @dataset.blank?
			em = Emitter.new(format)
			em.load_template :entry
			hook :before_save, :file => file, :format => format
			File.open(file, 'w+')	do |f|
				header = hook :saved_file_header, :format => format
				f.write header unless header.blank?
				@dataset.each do |entry|
					f.write em.render(:entry, :entry => entry)
				end
				footer = hook :saved_file_footer , :format => format
				f.write footer unless footer.blank?
			end
			hook :after_save, :file => file
		end
		
		# Redefine Messaging::debug
		alias m_debug debug

		# Toggles debug output.
		def debug
			RedBook.debug = !RedBook.debug
		end

		# Toggles standard output.
		def output
			RedBook.output = !RedBook.output
		end

		# Evaluates a string as Ruby code.
		def ruby(string)
			instance_eval string
		end	


		private

		def create_repository
			Repository.reset
		end

		def insert_entry(attributes={})
			# Delete unknown attributes
			attrs = attributes.dup
			attrs.each_pair do |l, v|
				attrs.delete l unless [:text, :timestamp, :type].include? l
			end
			entry = Repository::Entry.new attrs
			raise Exception, "Entry text not specified" unless attrs[:text] 
			entry.type = "entry"
			entry.timestamp = Time.now unless attrs[:timestamp]
			entry.save
			entry
		end

		def update_entry(index, attributes={})
			# Delete unknown attributes
			attributes.each_pair do |l, v|
				attributes.delete l unless [:text, :timestamp, :type].include? l
			end
			raise EngineError, "Empty index" if @dataset.blank?
			raise EngineError, "Invalid dataset index" unless index >=0 && index < @dataset.length
			raise EngineError, "Nothing to update" if attributes.blank?
			entry = @dataset[index]
			entry.attributes = attributes
			entry.save
			entry
		end
		
		def delete_entry(entry)
			entry.destroy
			entry
		end

		def select_entries(attributes={})
			attrs = attributes.dup
			limit, type = attrs.delete(:first), :first if attrs[:first]
			limit, type = attrs.delete(:last), :last if attrs[:last]
			# Delete unknown attributes
			attrs.each_pair do |l, v|
				attrs.delete l unless [:text, :timestamp, :type].include? l
			end
			type ||= :select	
			case type
			when :select then
				Repository::Entry.all(attrs)
			when :first then
				Repository::Entry.first(limit, attrs)
			when :last then
				attrs[:order] = [:timestamp.desc]
				Repository::Entry.first(limit, attrs)
			end
		end

	end
end

# Implementing hooks for saving XML and XHTML files

RedBook::Engine.define_hook :saved_file_header do |params|
	result = ""
	case params[:format]
	when :xml then
		result <<	"<xml version=\"1.0\" encoding=\"UTF-8\">\n"
		result << "<dataset>\n"
	when :html||:xhtml then
		result << "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n"
		result << "<head>\n"
		result << "	<title>RedBook Dataset</title>\n"
		result << "</head>\n"
		result << "<body>\n"
		result << "<h1>RedBook Dataset</h1>\n"
		result << "<div id=\"dataset\">\n"
	end
	result
end

RedBook::Engine.define_hook :saved_file_footer do |params|
	result = ""
	case params[:format]
	when :xml then
		result << "\n</dataset>\n"
	when :html||:xhtml then
		result << "\n</div>\n"
		result << "</body>\n"
	end
	result
end

		
		
	
