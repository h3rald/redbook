#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

defining_hook = lambda do
	RedBook::HookTest.define_hook(:test) do |params|
		{:value => params[:a]+params[:b], :stop => false}
	end
end

using_hook = lambda do
	class RedBook::HookTest
		include RedBook::Hookable
		attr_reader :result
		def do_something
			@result = hook(:test, :a => 2, :b => 10)
		end
	end
end

describe RedBook::Hook do

	it "should allow hooks to be called inside methods" do
		using_hook.should_not raise_error
	end
	
	it "should allow hooks to be defined" do
		using_hook.call
		defining_hook.should_not raise_error
	end

	it "should allow multiple hooks to be defined" do
		using_hook.call
		defining_hook.should_not raise_error
		defining_hook.should_not raise_error
	end

	it "should allow execution of hooks" do
		using_hook.call
		defining_hook.call
		test = RedBook::HookTest.new
		test.do_something
		test.result.should == 12
	end

	it "should stop execution of hooks if necessary" do
		using_hook.call
		defining_hook.call
		RedBook::HookTest.define_hook(:test) do |params|
			{:value => params[:a]*params[:b], :stop => true }
		end
		defining_hook.call
		test = RedBook::HookTest.new
		test.do_something
		test.result.should == 20
	end

end
