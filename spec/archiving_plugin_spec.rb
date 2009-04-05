#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

default_dir =  RedBook.config.archiving.directory.dup 

dir = Pathname(__FILE__).dirname.expand_path

describe RedBook::ArchivingPlugin do

	before(:each) do 
		RedBook.output = false
		RedBook.debug = false
		@db = dir/'test.rbk'.to_s
		@c = RedBook::Cli.new @db
		RedBook::Repository.reset
		@c.process "log Test #1"
		@c.process "log Test #2"
		@c.process "log Test #3"
		@c.process "log Test #4"
	end

	it "should backup the repository" do
		RedBook.config.archiving.directory = dir
		lambda { @c.process "backup" }.should_not raise_error
		(dir/'test.rbk.bak').exist?.should == true
	end

	it "should archive the repository" do
		RedBook.config.archiving.directory = dir
		lambda { @c.process "archive" }.should_not raise_error
		dir.children.select{|f| f.to_s.match /\.zip/}.length.should > 0
	end

end

RedBook.config.archiving.directory = default_dir
