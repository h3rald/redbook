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
		@a.should_not raise_error
		@p.should_not raise_error
		@b.should_not raise_error
	end

	it "should allow updating of activities, processes and breaks" do
		@c.process ":select :type activity"
		@c.process ":update 1 :project Test2 :version 2.0 :ref 2000 :completion 2 seconds ago"
	end
	
	it "should allow selection of activities, processes and breaks" do
		@c.process ":log Testing :timestamp 2 days ago :completion 10 minutes ago :type process"
		@c.process ":select :type process :before 3 minutes ago"
		@c.engine.dataset.length.should == 1
		@c.process ":select :type process break activity"
		@c.engine.dataset.length.should == 4
		@c.process ":update 1 :type process :version 3.0 :project Test 3"
		@c.process ":select :type process :version 3.0 :project Test 3"
		@c.engine.dataset.length.should == 1
	end

	it "should start tracking time spent on an activity, process or break" do 
		lambda { @c.process ":start 1" }.should raise_error
		@c.engine.select
		@c.process ":start 1"
		a = @c.engine.dataset[0]
		p = @c.engine.dataset[1]
		a.activity.tracking.should == 'started'
		a.records.length.should == 1
		a.records[0].end.should == nil
		a.records[0].start.should_not be_blank
		# It should be possible to start an activity *and* a process at the same time
		@c.process ":start 2"
		p.activity.tracking.should == 'started'
		p.records.length.should == 1
		p.records[0].end.should == nil
		p.records[0].start.should_not be_blank
		sleep 1
		@c.process ":start 3" 
		@c.engine.select
		a = @c.engine.dataset[0]
		b = @c.engine.dataset[2]
		b.activity.tracking.should == 'started'
		b.records.length.should == 1
		b.records[0].end.should == nil
		b.records[0].start.should_not be_blank
		a.activity.tracking.should == 'paused'
		a.records.length.should == 1
		a.records[0].end.should_not be_blank
		a.records[0].start.should_not be_blank
	end

	it "should track time of started, paused and completed activities automatically" do
		@c.engine.select
		a = @c.engine.dataset[1] # activity
		p = @c.engine.dataset[2] # process
		b = @c.engine.dataset[0] # break
		@c.process ":start 1" # break
		@c.process ":start 2" # activity
		sleep 1
		@c.process ":start 3" # process
		sleep 2
		@c.process ":start 1" # break
		sleep 3
		@c.process ":finish 2"
		lambda {@c.process ":start 1" }.should raise_error # started
		lambda {@c.process ":pause 2" }.should raise_error # completed
		@c.process ":pause 1"
		@c.process ":pause 3"
		@c.engine.select
		a = @c.engine.dataset[1] # activity
		p = @c.engine.dataset[2] # process
		b = @c.engine.dataset[0] # break
		a.activity.duration.should >= 3.0/60
		p.activity.duration.should >= 5.0/60
		b.activity.duration.should >= 3.0/60
		a.activity.tracking.should == 'completed'
		# Duration can be overridden
		@c.process ":update 1 :duration 2"
		@c.engine.select
		b.activity.duration.should == 2
		b.records.length.should == 2
		p.records.length.should == 1
		b.records.length.should == 2
	end


	
end
