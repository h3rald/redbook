#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')



describe RedBook::TrackingPlugin do

	before(:each) do
		RedBook.output = false
		RedBook.debug = false
		@db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
		@c = RedBook::Cli.new @db
		RedBook::Repository.reset
		@a = lambda { @c.process ":log Test activity :type activity :project Test :version 1.0 :ref #001" }
		@p = lambda { @c.process ":log Test activity :type process :project Test :version 1.0 :ref #001 :duration 120" }
		@b = lambda { @c.process ":log Test activity :type break :timestamp 30 seconds ago :completion now" }
	end

	it "should allow creation of activities, processes and breaks" do
		@a.should_not raise_error
		@p.should_not raise_error
		@b.should_not raise_error
	end

	it "should allow updating of activities, processes and breaks" do
		@a.call
		@p.call
		@b.call
		@c.process ":select :type activity"
		@c.process ":update 1 :project Test2 :version 2.0 :ref 2000 :completion 2 seconds ago"
	end
	
	it "should allow selection of activities, processes and breaks" do
		@a.call
		@p.call
		@b.call
		@c.process ":log Testing :timestamp 2 days ago :completion 10 minutes ago :type process"
		@c.process ":select :type process :before 3 minutes ago"
		@c.engine.dataset.length.should == 1
		@c.process ":select :type process break activity"
		@c.engine.dataset.length.should == 4
		@c.process ":update 1 :type process :version 3.0 :project Test 3"
		@c.process ":select :type process :version 3.0 :project Test 3"
		@c.engine.dataset.length.should == 1
	end

	
end
