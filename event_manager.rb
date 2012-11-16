#Dependencies

require "csv"

#the sunlight gem. We call this a wrapper library because 
#its job is to hide complexity from us. We can interact with 
#it as a regular Ruby object, then the library takes care of 
#fetching and parsing data from the server.
require 'sunlight'

#Class Definition
class EventManager

	INVALID_PHONE_NUMBER = "0000000000"
	INVALID_ZIPCODE =      "00000"
	Sunlight::Base.api_key = "e179a6973728c4dd3fb1204283aaccb5"

	def initialize(file_name)
		puts "EventManager Initialized."
		
		#the csv object implements the Enumerable interface
		#meaning you can use the 'each' method to go through
		#the file one by one. 
		@file = CSV.open(file_name, {:headers => true, 
			:header_converters => :symbol} )
			#header_converters makes header formatting consistent.
	end

	def print_names
		@file.each do |line|
			#puts line.inspect	#just shows literal rows
			 puts "#{line[:first_name]} #{line[:last_name]}"
		end
	end

	def clean_numbers(original)
		
			clean_number = original.gsub(/\D/, "")

			if clean_number.length == 10
				clean_number
			elsif clean_number.length == 11
				if 	clean_number.start_with?("1")
						clean_number = clean_number[1..-1]
				else
						clean_number = INVALID_PHONE_NUMBER
				end
			else
				clean_number = INVALID_PHONE_NUMBER
			end
		clean_number  # Send the variable 'number' back to the method that called this method
	end

	def print_numbers
		@file.each do |line|
			clean_number = clean_numbers(line[:homephone])
		puts clean_number
		end
	end

	def clean_zipcodes(original)
		
		if original.nil? 
			original = INVALID_ZIPCODE
		elsif original.length < 5
			until original.length == 5
				original[0, 0] = "0"
			end
		else
			original
		end
		original
	end
			
	def print_zipcodes
		@file.each do |line|
			zipcode = clean_zipcodes(line[:zipcode])
			puts zipcode
		end
	end

	
	# Outputs a CSV file w/ the 'file_name' of your choosing
	# with all the data from the original file along with the properly
	# formatted zipcodes and home phone numbers. 
	def output_data(file_name)
		
		# "w" means 'write to a file'. If you dont specify this, 
		# it will default to rb (read-only binary mode) and you 
		# would get an error when trying to add to your csv file. 
		
		output = CSV.open(file_name, "w")
		@file.each do |line|
			
			# Checks whether the csv line object is the first one
			# if so, we ask the first line object to print the headers.
			if @file.lineno == 2 			#deletes the original first line.
				output << line.headers
			else

			#The line object is loaded into memory using the data in the 
			#original file. Since it’s in memory, we can make changes to 
			#line itself without affecting the original file.
				line[:homephone] = clean_numbers(line[:homephone])
				line[:zipcode] = clean_zipcodes(line[:zipcode])
				output << line
			end
		end
	end

	
	# Uses the Sunlight API to look up a registrants legislator based on
	# his/her zipcode. 
	def rep_lookup
		20.times do 
			#readline pulls one line from the csv file at a time.
			line = @file.readline  

			# Takes advantage of an API from the Sunlight Foundation 
			# to lookup the appropriate congresspeople.
			#API lookup goes here
			legislators = Sunlight::Legislator.all_in_zipcode(clean_zipcodes(line[:zipcode]))
			
			#That last line looks a little funny because it isn’t being stored
			#anywhere. The last line of a block is going to create the "return
			#value" for the whole block.
			names = legislators.collect do |leg|
				first_initial = leg.firstname[0]
				last_name     = leg.lastname
				party_type    = leg.party
				title         = leg.title
				"#{title} #{first_initial}. #{last_name} (#{party_type})"
			end
			puts "#{line[:last_name]}, #{line[:first_name]}, #{line[:zipcode]}, #{names.join(", ")}"
		end
	end

	
	# Creates an HTML form letter that automatically inputs the registrants
	# information. 
	def create_form_letters
		# .read loads the whole file as a string. 
		letter = File.open("form_letter.html", "r").read
		20.times do 
			line = @file.readline
			
			custom_letter = letter.gsub("#first_name", line[:first_name].to_s)
			custom_letter = custom_letter.gsub("#last_name", line[:last_name].to_s)
			custom_letter = custom_letter.gsub("#street", line[:street].to_s)
			custom_letter = custom_letter.gsub("#city", line[:city].to_s)
			custom_letter = custom_letter.gsub("#state", line[:state].to_s)
			custom_letter = custom_letter.gsub("#zipcode", line[:zipcode].to_s)

			filename = "output/thanks_#{line[:last_name]}_#{line[:first_name]}.html"
			output = File.new(filename, "w")
			output.write(custom_letter)
		end
	end

	
    # Show which hours of the day the most people registerd.  
	def rank_times
		hours = Array.new(24) {0}
		@file.each do |line|
			timestamp = line[:regdate]
			hour = timestamp.split(" ")
			hour = hour[1].split(":")
			hour = hour[0].split.join
			hours[hour.to_i] += 1
		end
		hours.each_with_index {|counter, hours| puts "#{hours}\t#{counter}"}
	end

	
	# Shows which days of the week the most people registerd. 
	def day_stats
		days = Array.new(7) {0}
		@file.each do |line|
			date_stamp = line[:regdate]
			date = date_stamp.split(" ")
			date = date[0].split.join
			date = Date.strptime(date, "%m/%d/%y")
			day = date.wday
			days[day] = days[day] + 1
		end
		days.each_with_index {|counter, day| puts "#{day}\t#{counter}"}
	end

	
	# Returns states of regitrants in alphabetical order, along with the number
	# of registrants in those states, and where that state ranks in terms of
	# highest or lowest number of registrants. 
	def state_stats
		state_data = {}
		@file.each do |line|
			state = line[:state]	  #find the state
			if state_data[state].nil? #does the states key exist in state_date
				state_data[state] = 1 #if not, start w/ this one person.
			else
				state_data[state] += 1 #if the key exists, add one. 
			end
		end
		
		# rank orders the list by '-counter' (greatest to least)
		# after we have that specified order, knowing the actual count
		# is not important. The collect method pulls out the state names
		# in that specified order and assigns the array to 'ranks'.
		ranks = state_data.sort_by{|state, counter| -counter}.collect{|state, counter| state}
		state_data = state_data.select{|state, counter| state}.sort_by{|state, counter| state}
		state_data.each do |state, counter|
			
			# looks in the 'ranks' list and finds the index position of
			# whatever state is in the 'state' variable. Then adds 1 to
			# it. Since an array is indexed starting at 0, we add one
			# to the index position to start the rankings at 1. 
			# After the sorting above, the state w/ the highest rank
			# will be indexed at 0 so we add 1 to it. Giving it the #1
			# rank. 
			puts "#{state}:\t#{counter}\t(#{ranks.index(state) + 1})"
		end
	end
end

#Script
manager = EventManager.new("event_attendees.csv")
#manager.output_data("event_attendees_clean.csv")
manager.state_stats
