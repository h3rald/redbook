#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::TrackingPlugin do

	before(:each) do
		RedBook.output = false
		RedBook.debug = false
		@db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
		@c = RedBook::Cli.new @db
		RedBook::Repository.reset
		@a = lambda { @c.process ":log Current activity :type activity :project Test :version 1.0 :ref #001" }
		@p = lambda { @c.process ":log Background activity :type activity :project Test :version 1.0 :foreground no :ref #001 :duration 120" }
		@b = lambda { @c.process ":log Old activity :type activity :timestamp 30 seconds ago :completion now" }
		@a.should_not raise_error
		@p.should_not raise_error
		@b.should_not raise_error
	end

	it "should allow updating of activities" do
		@c.process ":select"
		@c.process ":update 1 :project Test2 :version 2.0 :ref 2000 :completion 2 seconds ago"
		lambda { @c.process ":update 1 :tracking disabled" }.should raise_error
		lambda {@c.process ":foreground 3" }.should_not raise_error
		@c.process ":select :foreground true"
		@c.engine.dataset.length.should == 3
		lambda {@c.process ":background 2" }.should_not raise_error
		@c.process ":select :foreground true"
		@c.engine.dataset.length.should == 2
	end

	it "should allow deletion of activities" do
		@c.process ":select"
		@c.process ":update 1 :timestamp 1 hour ago"
		@c.process ":track 1 :from 20 minutes ago :to 10 minutes ago"
		@c.process ":track 1 :from 9 minutes ago :to 7 minutes ago"
		@c.process ":track 1 :from 6 minutes ago :to 3 minutes ago"
		@c.engine.dataset[0].activity.tracked_duration.to_i.should == 15
		id = @c.engine.dataset[0].id 
		@c.engine.delete([1])
		RedBook::Repository::Entry.first(:id => id).should ==  nil
		RedBook::Repository::Activity.first(:entry_id => id).should ==  nil
		RedBook::Repository::Record.all(:entry_id => id).should ==  []
	end
	
	it "should allow selection of activities" do
		@c.process ":log Testing :timestamp 2 days ago :completion 10 minutes ago :type process"
		@c.process ":select :foreground no"
		@c.engine.dataset.length.should == 1
		@c.process ":select :longerthan 119"
		@c.engine.dataset.length.should == 1
		@c.process ":update 1 :type activity :version 3.0 :project Test 3"
		@c.process ":select :type activity :version 3.0 :project Test 3"
		@c.engine.dataset.length.should == 1
	end

	it "should start tracking time spent on an activity" do 
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
		p = @c.engine.dataset[2] # bkg activity
		b = @c.engine.dataset[0] # old activity
		@c.process ":start 1" # old activity
		@c.process ":start 2" # activity
		sleep 1
		@c.process ":start 3" # bkg activity
		sleep 2
		@c.process ":start 1" # old activity
		sleep 3
		@c.process ":finish 2"
		lambda {@c.process ":start 1" }.should raise_error # started
		lambda {@c.process ":pause 2" }.should raise_error # completed
		@c.process ":pause 1"
		@c.process ":pause 3"
		@c.engine.select
		a = @c.engine.dataset[1] # activity
		p = @c.engine.dataset[2] # bkg activity
		b = @c.engine.dataset[0] # old activity
		a.activity.duration.should >= 1.0/60
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

	it "should be possible to update tracking records" do
		@c.process ":select"
		@c.process ":update 1 :timestamp 2 hours ago :completion 30 minutes ago"
		lambda {@c.process ":track 1 :from 3 hours ago" }.should raise_error
		lambda {@c.process ":track 1 :from 3 hours ago :to now" }.should raise_error
		lambda {@c.process ":track 1" }.should raise_error
		lambda {@c.process ":track 1 :from 1 hour ago :to 55 minutes ago" }.should_not raise_error
		lambda {@c.process ":track 1 :from 54 minutes ago :to 52 minutes ago" }.should_not raise_error
		lambda {@c.process ":track 1 :from 40 minutes ago :to 34 minutes ago" }.should_not raise_error
		lambda {@c.process ":track 1 :from 35 minutes ago :to 29  minutes ago" }.should raise_error
		lambda {@c.process ":track 1 :from 31 minutes ago :to 25  minutes ago" }.should_not raise_error
		a = @c.engine.dataset[0]
		a.activity.duration.to_i.should == 19
		a.activity.tracking.should == 'completed'
		lambda {@c.process ":untrack 1 :from 61 minutes ago :to 54 minutes ago" }.should_not raise_error
		a.activity.duration.to_i.should == 14
		lambda {@c.engine.untrack(1) }.should_not raise_error
		RedBook::Repository::Record.all(:entry_id => a.id).length.should == 0
		a.activity.tracking.should == 'disabled'
	end
end
