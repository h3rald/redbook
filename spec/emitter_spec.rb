#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

describe RedBook::Emitter do

	it "should be instantiated for a specific format" do
		lambda { RedBook::Emitter.new(:txt) }.should_not raise_error
	end

	it "should load and render templates" do
		emitter = RedBook::Emitter.new(:txt)
		m = emitter.render(:message, :message => msg(:info, "Test #1"))
		m.should == "[info] Test #1\n"
	end

	it "should cache templates" do
		emitter = RedBook::Emitter.new(:txt, true)
		emitter.templates[:message].evaluate(:message => msg(:warning, "Test #2")).should == "[warning] Test #2\n"
	end
end
	
