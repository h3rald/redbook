#!/usr/bin/env ruby

# Defining default operations

module RedBook

	operation(:log){
		target { set :required;	rewrite_as :text }
		parameter(:timestamp) { type :time }
		parameter :type 
	}

	operation_alias :insert => :log

	operation(:select){
		target { rewrite_as(:text.like){|v| "%#{v}%" }}
		parameter(:from) { type :time; rewrite_as(:timestamp.gt) }
		parameter(:to) { type :time; rewrite_as(:timestamp.lt)}
		parameter(:type)  { type :list}
		parameter(:first) { type :integer }
		parameter(:last) { type :integer }
	}

	operation_alias :load => :select

	operation(:update){
		target { set :required; type :integer }
		parameter :text
		parameter(:timestamp) { type :time }
		parameter :type
	}

	operation(:delete) do
		target { type :intlist }
	end

	operation(:save){
		target { set :required }
		parameter(:format) { set :required; rewrite_as(:format){|v| v.to_sym} }
	}

	operation(:ruby){
		target { set :required }
	}

	operation(:rename){		
		target { set :required }
		parameter(:from) { set :required }
		parameter(:to) { set :required }
	}

	operation(:cleanup){
		target { type :list }
	}

	operation(:refresh){
		target { type :list }
	}

	operation(:use){
		target { set :required }
	}

	operation :quit
	operation :debug
	operation :output
	operation :color
	operation :dataset
	operation :clear

end
