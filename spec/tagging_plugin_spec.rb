#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::TaggingPlugin do

	before(:each) do
		RedBook.output = false
		@db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
		@c = RedBook::Cli.new @db
		RedBook::Repository.reset
	end

	it "should allow entries to be tagged" do
		@c.process ":log Testing tags :tags tag1 tag2"# }.should_not raise_error
		RedBook::Repository::Tag.all.length.should == 2
		RedBook::Repository::Tagmap.all.length.should == 2
	end
	it "should allow tagged entries to be retrieved" do
		@c.process ":log Testing tags :tags tag1 tag2"
		@c.process ":log Testing tags #2 :tags tag1"
		@c.process ":select :tags tag1"
		@c.engine.dataset.length.should == 2
		@c.process ":select :tags tag2"
		@c.engine.dataset.length.should == 1
	end

end
