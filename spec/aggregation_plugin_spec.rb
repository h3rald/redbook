#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'redbook')

describe RedBook::AggregationPlugin do

	before(:each) do 
		RedBook.output = false
		RedBook.debug = false
		@db = (Pathname(__FILE__).dirname.expand_path/'test.rbk').to_s
		@c = RedBook::Cli.new @db
		RedBook.config.calculation_fields[:type] = 'resource_type'
		RedBook::Repository.reset
		@c.process "log Test #1 -type 10"
		@c.process "log Test #2 -type 20"
		@c.process "log Test #3 -type 30"
		@c.process "log Test #4 -type 40"
		@c.process "select"
	end

	it "should calculate sum, average, max and min on numeric fields" do
		lambda { @c.process "calculate unknown -on type"}.should raise_error	
		@c.engine.calculate('sum', 'type').should == 100	
		@c.engine.calculate('max', 'type').should == 40	
		@c.engine.calculate('min', 'type').should == 10	
		@c.engine.calculate('average', 'type').should == 25	
  end
end
