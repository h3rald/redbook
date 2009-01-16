#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
t = Time.now
entries = []
entries << {:text => "First"}
entries << {:text => "Second", :type => 'entry'}
entries << {:text => "Third", :type => 'entry', :timestamp => Time.now}

describe RedBook::Engine do

	it "should create the repository if necessary" do
		e = RedBook::Engine.new db
		File.exist?(db).should == true				
	end

	it "should log entries" do
		RedBook::Repository.reset
		e = RedBook::Engine.new db
		log = lambda { |i| e.log entries[i] }
		lambda {log.call(0)}.should_not raise_error
		lambda {log.call(1)}.should_not raise_error
		lambda {log.call(2)}.should_not raise_error
		e.select.length.should == 3
	end

	it "should select entries" do
		RedBook::Repository.reset
		e = RedBook::Engine.new db
		entries.each { |entry| e.log entry }
		e.select(:text => "Second").length.should == 1
		e.select().length.should == 3
		e.select(:timestamp.gt => t).length.should == 3
		e.select(:type.like => "%ent%", :text.like => '%d%').length.should == 2
	end
end
