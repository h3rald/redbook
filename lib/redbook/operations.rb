#!/usr/bin/env ruby

# Defining default operations

module RedBook

	operation(:log){
		parameter(:log) { mandatory; rewrite_as :text }
		parameter(:timestamp) { type :time }
		parameter :type 
	}

	operation_alias :insert => :log

	operation(:select){
		parameter(:select) { rewrite_as(:text.like){|v| "%#{v}%" }}
		parameter(:from) { type :time; rewrite_as(:timestamp.gt) }
		parameter(:to) { type :time; rewrite_as(:timestamp.lt)}
		parameter(:type)  { type :list}
		parameter(:first) { type :integer }
		parameter(:last) { type :integer }
	}

	operation_alias :load => :select

	operation(:update){
		parameter(:update) { mandatory; type :integer }
		parameter :text
		parameter(:timestamp) { type :time }
		parameter :type
	}

	operation(:delete) do
		parameter(:delete) { type :intlist }
	end

	operation(:save){
		parameter(:save) { mandatory }
		parameter(:format) { mandatory; rewrite_as(:format){|v| v.to_sym} }
	}

	operation(:ruby){
		parameter(:ruby) { mandatory }
	}

	operation(:rename){		
		parameter(:rename) { mandatory }
		parameter(:from) { mandatory }
		parameter(:to) { mandatory }
	}

	operation(:cleanup){
		parameter(:cleanup) { type :list }
	}

	operation(:refresh){
		parameter(:refresh) { type :list }
	}

	operation(:use){
		parameter :use
	}

	operation :quit
	operation :debug
	operation :output
	operation :color
	operation :dataset
	operation :clear

end
