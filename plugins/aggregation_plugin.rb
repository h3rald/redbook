#!/usr/bin/env ruby

module RedBook
	class AggregationPlugin < Plugin
	end

	class Cli

		def calculate_operation(params)
			result = @engine.calculate params[:calculate], params[:on]
			info "Result #{result}"
		end

	end
	
	class Parser

		operation(:calculate) do |o|
			o.parameter(:calculate) { |p| p.required = true; p.type = :enum; p.values = ['sum', 'average', 'max', 'min']}
			o.parameter(:on) { |p| p.required = true }
		end

		macro :duration, ":calculate sum :on duration"
		macro :sum, ":calculate sum :on <:sum>"
		macro :min, ":calculate min :on <:max>"
		macro :max, ":calculate max :on <:max>"
		macro :average, ":calculate average :on <:average>"

	end

	class Engine

		def calculate(function, field)
			raise EngineError, "Empty dataset." if @dataset.blank?
			data = []
			sum = 0
			fields = {}
			@dataset.each do |e|
				f = hook(:get_calculation_field, :entry => e, :field => field) || nil
				next unless f
				data << f
				sum += f
			end
			case function.to_sym
			when :sum then
				return sum
			when :average then
				return sum/data.length
			when :max then
				return data.sort.reverse[0]
			when :min then
				return data.sort[0]
			else
				raise EngineError, "Function '#{function}' not supported."
			end
		end

		define_hook(:get_calculation_field) do |params|
			result = nil
			if params[:field] == 'duration' then
				begin
					result = params[:entry].activity.duration
				rescue
					nil
				end
			end
			{:value => result, :stop => result ? true : false}
		end

	end

end
