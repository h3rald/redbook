#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::DetailPlugin do

	before(:each) do
		RedBook.output = false
		RedBook.debug = false
		@db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
		@c = RedBook::Cli.new @db
		RedBook::Repository.reset
	end

	it "should allow entries to be extended through details" do
		@c.process "log Testing details -code AB001 -notes Random notes"
		@c.process "select"
		e = @c.engine.dataset[0]
		e.get_detail(:notes).should == "Random notes"
		e.get_field(:code).should == "AB001"
	end

	it "should allow entries to be extended through items" do
		@c.process "log Testing items -project RedBook -version 1.0"
		@c.process "select"
		e = @c.engine.dataset[0]
		e.get_item(:project).should == "RedBook"
		e.get_field(:version).should == "1.0"
	end

	it "should allow details and items to be updated" do
		@c.process "log Testing items -project RedBook -version 1.0"
		@c.process "log Testing details -code AB001 -notes Random notes"
		@c.process "select"
		@c.process "update 1 -project Test"
		@c.process "update 2 -code AB002 -notes More notes"
		it = @c.engine.dataset[0]
		dt = @c.engine.dataset[1]
		it.get_item(:project).should == "Test"
		dt.get_detail(:code).should == "AB002"
		dt.get_field(:notes).should == "More notes"
	end

	it "should allow entries to be filtered by projects and items" do
		@c.process "log Testing items -project RedBook -version 1.0"
		@c.process "log Testing details -code AB001 -notes Random notes"
		@c.process "log Testing details -code AB002 -notes Something else"
		@c.process "log Testing details and items -project RedBook -code AB002 -notes Something else"
		@c.process "select -project RedBook"
		@c.engine.dataset.length.should == 2
		@c.process "select -project RedBook -notes Random"
		@c.engine.dataset.length.should == 0
		@c.process "select -code AB00" 
		@c.engine.dataset.length.should == 3
		@c.process "select -code AB00 -notes Rand" 
		@c.engine.dataset.length.should == 1
	end
end
