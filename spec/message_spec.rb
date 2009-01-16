#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

class TestObserved
	include RedBook::Messaging

	def initialize(o=nil)
		add_observer o if o
	end

	def do_something
		info "Something"
	end
end

class TestObserver
	
	attr_accessor :data

	def update(data)
		@data = data
	end
end

describe RedBook::Message do

	it "is defined by specifying a name and a value" do
		lambda { msg("test", "test #1") }.should raise_error
		lambda { msg(:test, "test #2") }.should_not raise_error
		msg = msg(:test, "test #1")
		msg.name.should == :test
		msg.value.should == "test #1"
	end

	it "may contain children" do
		msg = msg(:test1, "test #1")
		lambda { msg << "this won't work..." }.should raise_error
		lambda { msg << msg(:test2, "test #2") }.should_not raise_error
		lambda { msg << msg(:test3, msg(:test, "error..."))}.should raise_error
	end

	it "allows children to be accessed via /" do
		msg = msg(:test1, "test #1")
		msg << msg(:test2, "test #2a")
		msg << msg(:test2, "test #2b")
		msg << msg(:test2, "test #2c")
		msg << msg(:test3, "test #3")
		(msg/:test2).length.should == 3
		(msg/:test4).should == []
	end

	it "may have attributes" do
		msg = msg(:test1, "test #1")
		lambda { msg <= {:a => 1, :b => 2, :c => 3} }.should_not raise_error
		lambda { msg <= {:b => 4, :c => 6, :d => 8} }.should_not raise_error
		msg.attributes.should == {:a => 1, :b => 4, :c => 6, :d => 8}
	end

	it "allows attributes to be accessed via []" do
		msg = msg(:test1, "test #1")
		msg <= {:a => 1, :b => 2}
		msg[:a].should == 1
		msg[:b].should == 2
	end

	it "supports recursion on children" do
		msg = msg(:test, 1)
		msg << msg(:test, 2) 
		msg << msg(:test, 3) << msg(:test, 4)
		msg << msg(:test, 5) 
		msg << msg(:test, 6) << msg(:test, 7)
		result = 0
		msg.recurse {|c| result += c.value}
		result.should == 28
	end

end

describe RedBook::Messaging do

	it "should define standard message types" do
		a = TestObserved.new
		a.info("hello!").name.should == :info
		a.warning("hello!").name.should == :warning
		a.error("hello!").name.should == :error
		RedBook.debug = true
		a.debug("hello!").name.should == :debug
	end

	it "should be observable" do
		observer = TestObserver.new
		observed = TestObserved.new(observer)
		observed.do_something
		observer.data.name.should == :info
		observer.data.value.should == "Something"
	end
end

