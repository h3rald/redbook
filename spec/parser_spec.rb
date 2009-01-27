#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

describe RedBook::Parser do
	
	it "should define :log operation" do
		op= RedBook::Parser.operations[:log]
		op.should_not == nil
		op.name.should == :log
		op.post_parsing.should_not == nil
		op.params[:log].should_not == nil
		op.params[:timestamp].should_not == nil
		op.params[:type].should_not == nil
	end

	it "should define :select operation" do
		op = RedBook::Parser.operations[:select]
		op.should_not == nil
		op.name.should == :select
		op.post_parsing.should_not == nil
		op.params[:select].should_not == nil
		op.params[:from].should_not == nil
		op.params[:to].should_not == nil
		op.params[:type].should_not == nil
	end

	it "should define :update operation" do
		op= RedBook::Parser.operations[:update]
		op.should_not == nil
		op.name.should == :update
		op.post_parsing.should_not == nil
		op.params[:update].should_not == nil
		op.params[:timestamp].should_not == nil
		op.params[:text].should_not == nil
		op.params[:type].should_not == nil
	end

	it "should define :delete operation" do
		op= RedBook::Parser.operations[:delete]
		op.should_not == nil
		op.name.should == :delete
		op.post_parsing.should_not == nil
		op.params[:delete].should_not == nil
	end

	it "should define :save operation" do
		op= RedBook::Parser.operations[:save]
		op.should_not == nil
		op.name.should == :save
		op.post_parsing.should_not == nil
		op.params[:save].should_not == nil
		op.params[:format].should_not == nil
	end

	it "should parse :log operations" do
		p = RedBook::Parser.new
		op = p.parse ":log Something :timestamp 3 minutes ago"
		op[0].should == :log
		op[1][:text].should == "Something"
		op[1][:timestamp].class.should == Time
	end

	it "should parse :select operations" do
		p = RedBook::Parser.new
		op = p.parse ":select something :from today at 8 am :to today at 10 am"
		op[0].should == :select
		op[1].each_pair do |key, value|
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

	it "should parse :update operations" do
		p = RedBook::Parser.new
		op = p.parse ":update 4 :text something"
		op[0].should == :update
		op[1][0].should == 4
		op[1][1][:text].should == "something"
		op[1][1][:timestamp].should == nil
	end

	it "should parse :delete operations" do
		p = RedBook::Parser.new
		op = p.parse ":delete 3"
		op[0].should == :delete
		op[1].should == 3
	end

	it "should parse :save operations" do
		p = RedBook::Parser.new
		op = p.parse ":save /home/h3rald/test.txt :format txt"
		op[0].should == :save
		op[1][0].should == "/home/h3rald/test.txt"
		op[1][1].should == :txt
	end

	it "should allow operations to be modified at runtime" do
		RedBook::Parser.operations[:log].parameter(:tags) {|p| p.type = :list}
		p = RedBook::Parser.new
		op = p.parse ":log test :tags tag1 tag2 tag3"
		op[1][:text].should == "test"
		op[1][:tags].should == ['tag1', 'tag2', 'tag3']
	end

	it "should detect invalid operations" do
		p = RedBook::Parser.new
		lambda { p.parse ":error This won't work" }.should raise_error
		lambda { p.parse ":update something :text This won't work" }.should raise_error
		lambda { p.parse ":update 1 :timestamp This won't work" }.should raise_error
	end

end
