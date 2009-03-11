#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::Emitter do

	it "should be instantiated for a specific format" do
		lambda { RedBook::Emitter.new(:txt) }.should_not raise_error
	end

	it "should load and render templates" do
		emitter = RedBook::Emitter.new(:txt)
		m = emitter.render msg(:info, "Test #1")
		m.should == "[info] Test #1"
	end

	it "should cache templates" do
		emitter = RedBook::Emitter.new(:txt, true)
		helper = RedBook::Emitter::TxtHelper.new
		object = msg(:warning, "Test #2")
		emitter.templates[:'message.txt'].evaluate(:object => object, :helper => helper).should == "[warning] Test #2\n"
	end
end
	
