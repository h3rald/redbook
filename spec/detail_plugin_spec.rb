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
		e.get_detail(:notes).name.should == "Random notes"
		e.get_detail(:code).name.should == "AB001"
	end

	it "should allow entries to be extended through items" do
		@c.process "log Testing items -project RedBook -version 1.0"
		@c.process "select"
		e = @c.engine.dataset[0]
		e.get_item(:project).name.should == "RedBook"
		e.get_item(:version).name.should == "1.0"
	end

	it "should allow details and projects to be updated" do
		@c.process "log Testing items -project RedBook -version 1.0"
		@c.process "log Testing details -code AB001 -notes Random notes"
		@c.process "select"
		@c.process "update 1 -project Test"
		@c.process "update 2 -code AB002 -notes More notes"
		it = @c.engine.dataset[0]
		dt = @c.engine.dataset[1]
		it.get_item(:project).name.should == "Test"
		dt.get_detail(:code).name.should == "AB002"
		dt.get_detail(:notes).name.should == "More notes"
	end



end
