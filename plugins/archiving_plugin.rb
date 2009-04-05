#!/usr/bin/env ruby

require 'fileutils'
require 'zip/zipfilesystem'


module RedBook
	class ArchivingPlugin < Plugin
	end

	operation(:backup) {
		body { |params|
			name = Pathname.new(@engine.db).basename
			info "Backing up '#{name}'..."
			@engine.copy_file(@engine.db, RedBook.config.archiving.directory)
			info "Done."
		}
	}

	operation(:archive) {
		body { |params|
			name = Pathname.new(@engine.db).basename
			info "Archiving '#{name}'..."
			@engine.zip_file(@engine.db, RedBook.config.archiving.directory)
			info "Done."
		}
	}

	class Engine

		def copy_file(file, dir)
			name = Pathname.new(file).basename.to_s+'.bak'
			dest = dir/name
			FileUtils.mkpath dir rescue raise(EngineError, "Unable to create directory '#{dir}'")
			FileUtils.cp file, dest rescue raise(EngineError, "Copy failed.")
		end

		def zip_file(file, dir)
			name = Pathname.new(file).basename.to_s.gsub /\.(.+)$/, "_#{Time.now.strftime("%Y-%m-%d@%H-%M-%S")}.zip"
			dest = dir/name
			Zip::ZipFile.open(dest.to_s, Zip::ZipFile::CREATE) { |zipfile|	zipfile.add file.basename.to_s, file.to_s } \
				rescue raise(EngineError, "Unable to compress file")
		end

	end

end
