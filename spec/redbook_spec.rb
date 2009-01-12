#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'..','lib', 'rbk-core')

describe RedBook do

	it "should load a configuration file" do 
		RedBook.setup
		RedBook.config.class.should == Hash
	end

end

