#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

class RedBook::HookTest

	include RedBook::Hookable

	attr_reader :result
	
	def initialize
		@result = 0
	end

end

defining_hook = lambda do
	RedBook::Hook.new(RedBook::HookTest, :test) do |params|
		params[:a]+params[:b]
	end
end

defining_another_hook = lambda do
	RedBook::HookTest.define_hook(:test) do |params|
		params[:a]+params[:b]
	end
end

using_hook = lambda do
	class RedBook::HookTest
		def do_something
			@result = hook :test, :a => 2, :b => 10
		end
	end
end

describe RedBook::Hook do

	it "should allow hooks to be called inside methods" do
		using_hook.should_not raise_error
	end
	
	it "should allow hooks to be defined" do
		using_hook
		defining_hook.should_not raise_error
	end

	it "should allow multiple hooks to be defined" do
		using_hook
		defining_hook.should_not raise_error
		defining_another_hook.should_not raise_error
	end

	it "should allow execution of hooks" do
		using_hook
		defining_hook
		test = RedBook::HookTest.new
		test.do_something
		test.result.should == 12
	end

	it "should stop execution of hooks if necessary" do
		using_hook
		defining_hook
		stoppable = RedBook::Hook.new(RedBook::HookTest, :test, true) do |params|
			params[:a]*params[:b]
		end
		defining_another_hook
		test = RedBook::HookTest.new
		test.do_something
		test.result.should == 20
	end

end
