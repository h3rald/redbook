#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
setup = lambda { RedBook::Repository.setup("sqlite3://"+db) }

describe RedBook::Repository do

	it "should setup to a SQLite database" do
		setup.should_not raise_error	
	end

	it "should create a new database" do
		RedBook::Repository.reset
	end

end


