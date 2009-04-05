#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

class TestObserved
	include RedBook::Messaging

	def initialize(o=nil)
		add_observer o if o
	end

	def do_something
		info "Something"
	end
	
	def do_something_else
		warning "Something else"
	end
end

class TestObserver
	
	attr_accessor :data

	def update(data)
		@data = data
	end
end

describe RedBook::Messaging do

	it "should define standard message types" do
		RedBook.output = true
		a = TestObserved.new
		a.info("hello!").name.should == :info
		a.warning("hello!").name.should == :warning
		a.error("hello!").name.should == :error
		RedBook.debug = true
		a.debug("hello!").name.should == :debug
	end

	it "should be observable" do
		RedBook.output = true
		observer = TestObserver.new
		observed = TestObserved.new(observer)
		observed.do_something
		observer.data.name.should == :info
		observer.data.value.should == "Something"
	end
end

