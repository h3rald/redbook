#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::TaggingPlugin do

	before(:each) do
		RedBook.output = false
		RedBook.debug = false
		@db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
		@c = RedBook::Cli.new @db
		RedBook::Repository.reset
	end

	it "should allow entries to be tagged" do
		lambda { @c.process "log Testing tags -tags tag1 tag2" }.should_not raise_error
		lambda { @c.process "log Testing tags #2 -tags tag1 tag3" }.should_not raise_error
		RedBook::Repository::Tag.all.length.should == 3
		RedBook::Repository::TagMap.all.length.should == 4
	end

	it "should allow tagged entries to be retrieved" do
		@c.process "log Testing tags -tags tag1 tag2"
		@c.process "log Testing tags #2 -tags tag1"
		@c.process "log Testing tags #3 -tags tag3"
		@c.process "log Testing tags #4"
		@c.process "select -tags tag3"
		@c.engine.dataset.length.should == 1
		@c.process "select -tags tag1"
		@c.engine.dataset.length.should == 2
		@c.process "select"
		@c.engine.dataset.length.should == 4
		@c.process "select -tags tag1 tag2"
		@c.engine.dataset.length.should == 1
	end

	it "should allow tags associated to an entry to be updated" do
		@c.process "log Testing tag update -tags tag1 tag2"
		@c.process "select"
		@c.process "update 1 -tags tag3"
		@c.process "select -tags tag3"
		@c.engine.dataset.length.should == 1
		@c.process "select tags tag2"
		@c.engine.dataset.length.should == 0
	end

	it "should delete all associated tags when an entry is deleted" do
		@c.process "log Testing tag delete -tags tag1 tag2"
		@c.process "log Testing tag delete -tags tag2 tag3"
		@c.process "log Testing tag delete -tags tag1 tag3"
		@c.process "select"
		@c.engine.delete
		RedBook::Repository::TagMap.all.length.should == 0
		RedBook::Repository::Tag.all.length.should == 3
	end

	it "should be possible to cleanup unused tags" do
		@c.process "log Testing cleanup -tags tag1 tag2"
		@c.process "insert Testing cleanup -tags tag3 tag2"
		@c.process "select -tags tag3"
		@c.engine.delete
		lambda { @c.process "cleanup tags" }.should_not raise_error
		RedBook::Repository::Tag.first(:name => 'tag3').should == nil
	end

	it "should be possible to add and remove tags to entries" do
		@c.process "log Testing add+ -tags tag1"
		@c.process "log Testing add+ -tags tag1 tag2"
		@c.process "select"
		@c.process "tag -as tag2 tag3 tag1 tag4"
		@c.process "tag 1 -as tag5"
		@c.process "load -tags tag1 tag2 tag3 tag4"
		@c.engine.dataset.length.should == 2
		@c.process "select -tags tag5"
		@c.engine.dataset.length.should == 1
		@c.process "untag 1 -as tag2 tag3"
		@c.process "load -tags tag2 tag3"
		@c.engine.dataset.length.should == 1
	end

	it "should allow tags to be renamed" do
		@c.process "insert Testing renaming -tags test" 
		@c.process "insert Testing renaming -tags test2" 
		@c.process "insert Testing renaming -tags test3" 
		@c.engine.select
		@c.process "rename tag -from test -to test1"
		RedBook::Repository::Tag.first(:name => 'test1').should_not == nil
		@c.engine.dataset[0].tags[0].name.should == 'test1'
		# Merge if tag exists
		RedBook::Repository::Tag.all.length.should == 3
		@c.process "rename tag -from test2 -to test1"
		@c.process "rename tag -from test3 -to test1"
		RedBook::Repository::Tag.all(:name => 'test1').length.should == 1
		RedBook::Repository::Tag.all.length.should == 1
	end
end
