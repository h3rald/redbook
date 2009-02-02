#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
t = Time.now
entries = []
entries << {:text => "First"}
entries << {:text => "Second", :type => 'entry'}
entries << {:text => "Third", :type => 'entry', :timestamp => Time.now}

describe RedBook::Engine do

	before(:each) do
		RedBook::Repository.reset
		@e = RedBook::Engine.new db
	end

	it "should create the repository if necessary" do
		File.exist?(db).should == true				
	end

	it "should log entries" do
		log = lambda { |i| @e.log entries[i] }
		lambda {log.call(0)}.should_not raise_error
		lambda {log.call(1)}.should_not raise_error
		lambda {log.call(2)}.should_not raise_error
		@e.select.length.should == 3
	end

	it "should select entries" do
		entries.each { |entry| @e.log entry }
		@e.select(:text => "Second").length.should == 1
		@e.select().length.should == 3
		@e.select(:timestamp.gt => t).length.should == 3
		@e.select(:type.like => "%ent%", :text.like => '%d%').length.should == 2
		@e.select(:last => 2).length.should == 2
		@e.select(:first => 1).length.should == 1
		last2 = @e.select.reverse
		last2.pop
		@e.select(:last => 2).should == last2
	end

	it "should add selected entries to the dataset" do
		entries.each { |entry| @e.log entry }
		@e.select
		@e.dataset.length.should == 3
		@e.select(:text.like => '%d%')
		@e.dataset.length.should == 2
	end

	it "should update an entry loaded in the current dataset" do
		RedBook::Repository.reset
		e = RedBook::Engine.new db
		entries.each { |entry| e.log entry }
		lambda { e.update 1, :text => "Updated #2"}.should raise_error
		e.select
		lambda { e.update 1, :text => "Updated #2"}.should_not raise_error
		e.select(:text.like => "%#2").length.should == 1
	end

	it "should delete entries loaded in the current dataset" do
		entries.each { |entry| @e.log entry }
		lambda { @e.delete [1]}.should raise_error
		@e.select
		lambda { @e.delete [1]}.should_not raise_error
		@e.select.length.should == 2
		lambda { @e.delete }.should_not raise_error
		@e.select.length.should == 0
	end

	it "should save the dataset to a file" do
		entries.each { |entry| @e.log entry }
		file = (Pathname(__FILE__).dirname.expand_path/'test.txt').to_s
		lambda { @e.save(file) }.should raise_error
		@e.select
		lambda { @e.save(file) }.should_not raise_error
		File.exist?(file).should == true
	end

	it "should allow renaming for named objects" do
		t = RedBook::Repository::Tag.new :name => 'tag1'
		t.save
		@e.rename :tag, 'tag1', 'new_tag'
		RedBook::Repository::Tag.first(:name => 'new_tag').should_not == nil
	end


end
