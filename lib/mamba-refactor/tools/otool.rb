module Mamba
	module Tools
		# Class to work with otool 
		class OTool 
			# Create an instance of the coverage class
			# @param [String] Path of the object file to interrogate
			# @returns nil if otool is not found
			def initialize(objectFile)
				@otool = find_executable0('otool')
				if(@otool == nil) then
					return(nil)
				end

				@needed = [objectFile]
				@found = Hash.new()

				# Hack for now, please convert to regex
				executablePathArr = objectFile.split(File::SEPARATOR)
				executablePathArr.pop()
				@executablePath = executablePathArr.join(File::SEPARATOR)
			end

			# Reads the shared libraries from an objects macho header
			def read_header()
				# Pull an object off the array
				object = @needed.shift()
				@found[object] = true

				# Find all shared libraries linked with the object
				output = ""
				ret = IO.popen("#{@otool} -L \"#{object}\"", 'r') do |f|
					output = f.read()
				end

				# Cleanup the output 
				linkedObjects = output.split("\n")
				linkedObjects.shift()

				# Cleanup the entries
				linkedObjects.each do |sharedObject|
					sharedObject.sub!(/\(.*\)/, '').strip!().chomp!()

					# Fix executable path variable in linker
					if(sharedObject.start_with?("@executable_path")) then
						sharedObject.gsub!(/@executable_path/, @executablePath)
					end

					if(!@found.has_key?(sharedObject)) then
						@needed.push(sharedObject)
					end
				end
			end

			# Start recursively interrogating object files with otool
			# @returns [Hash] All shared libraries found
			def gather_shared_libraries()
				begin
					read_header()
				end while(@needed.size() != 0)

				return(@found.keys.sort())
			end
		end
	end
end
