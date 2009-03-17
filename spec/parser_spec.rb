#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::Parser do

	before(:each) do
		@p = RedBook::Parser.new
	end
	
	it "should define log operation" do
		op= RedBook.operations[:log]
		op.should_not == nil
		op.name.should == :log
		op.parameters[:log].should_not == nil
		op.parameters[:timestamp].should_not == nil
		op.parameters[:type].should_not == nil
	end

	it "should define select operation" do
		op = RedBook.operations[:select]
		op.should_not == nil
		op.name.should == :select
		op.parameters[:select].should_not == nil
		op.parameters[:from].should_not == nil
		op.parameters[:to].should_not == nil
		op.parameters[:type].should_not == nil
	end

	it "should define update operation" do
		op= RedBook.operations[:update]
		op.should_not == nil
		op.name.should == :update
		op.parameters[:update].should_not == nil
		op.parameters[:timestamp].should_not == nil
		op.parameters[:text].should_not == nil
		op.parameters[:type].should_not == nil
	end

	it "should define delete operation" do
		op= RedBook.operations[:delete]
		op.should_not == nil
		op.name.should == :delete
		op.parameters[:delete].should_not == nil
	end

	it "should define save operation" do
		op= RedBook.operations[:save]
		op.should_not == nil
		op.name.should == :save
		op.parameters[:save].should_not == nil
		op.parameters[:format].should_not == nil
	end

	it "should parse log operations" do
		op = @p.parse "log Something -timestamp 3 minutes ago"
		op[0].should == :log
		op[1][:text].should == "Something"
		op[1][:timestamp].class.should == Time
	end

	it "should support alias operations" do
		op1 = @p.parse "log Test -timestamp 2 minutes ago -type test"
		op2 = @p.parse "insert Test -timestamp 2 minutes ago -type test"
		op1[1][:text].should == op2[1][:text]
		op1[1][:type].should == op2[1][:type]
		op1[0].should == :log
		op2[0].should == :insert
	end

	it "should parse select operations" do
		op = @p.parse "select something -from today at 8 am -to today at 10 am"
		op[0].should == :select
		op[1].each_pair do |key, value|
			if key.class == Symbol # it could also be a string/other, but it doesn't matter here. 
				case key.target
				when :text then
					value.should == "%something%"
					key.operator.should == :like
				when :timestamp then
					value.class.should == Time
					(key.operator == :lt || key.operator == :gt).should == true
				end	
			end
		end
	end

	it "should parse update operations" do
		op = @p.parse "update 4 -text something"
		op[0].should == :update
		op[1][:update].should == 4
		op[1][:text].should == "something"
		op[1][:timestamp].should == nil
	end

	it "should parse delete operations" do
		op = @p.parse "delete 3"
		op[0].should == :delete
		op[1][:delete].should == [3]
	end

	it "should parse save operations" do
		op = @p.parse "save /home/h3rald/test.txt -format txt"
		op[0].should == :save
		op[1][:save].should == "/home/h3rald/test.txt"
		op[1][:format].should == :txt
	end

	it "should allow operations to be modified at runtime" do
		RedBook.operations[:log].parameter(:test_tags) {type :list}
		op = @p.parse "log test -test_tags tag1 tag2 tag3"
		op[1][:text].should == "test"
		op[1][:test_tags].should == ['tag1', 'tag2', 'tag3']
		RedBook.operations[:log].parameters.delete :test_tags
	end

	it "should detect invalid operations" do
		p = RedBook::Parser.new
		lambda { p.parse "error This won't work" }.should raise_error
		lambda { p.parse "update something -text This won't work" }.should raise_error
		lambda { p.parse "update 1 -timestamp This won't work" }.should raise_error
	end

	it "should parse macros" do
		RedBook.macros[:test] = "log Testing <test>" 
		RedBook.macros[:bugfix] = "log Fixing <bugfix> -test_tags <test_tags> bugfix"
		# Macros can be recursive
	 	RedBook.macros[:urgfix]	= "bugfix <urgfix> -test_tags urgent"
		RedBook.operations[:log].parameter(:test_tags) { type :list}
		@p.parse("test GUI").should == @p.parse("log Testing GUI")
		# It should inherit the original operation's parameters
		@p.parse("test GUI -type bugfix").should == @p.parse("log Testing GUI -type bugfix")
		@p.parse("bugfix A12008 -test_tags low").should == @p.parse("log Fixing A12008 -test_tags low bugfix")
		@p.parse("urgfix A12008").should == @p.parse("log Fixing A12008 -test_tags urgent bugfix")
		lambda { p.parse ":wrong This won't work" }.should raise_error
		RedBook.operations[:log].parameters.delete :test_tags
	end

	it "should evaluate Ruby code" do
		@p.parse("log Test: %= 10*5 =%").should == @p.parse("log Test: 50")
		lambda {@p.parse("log %= @engine.dataset[0].text =%")}.should raise_error
		@p.parse("log Test: %= 60 *24*3=% and %=60*24=%").should == @p.parse("log Test: 4320 and 1440")
	end
end

