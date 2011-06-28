require 'zip/zip'
require 'mamba-refactor/algorithms/genetics/population'
require 'mamba-refactor/algorithms/genetics/chromosome'

module Mamba
	class SimpleGeneticAlgorithm <  Fuzzer
        DEFAULT_CROSSOVER_RATE = 0.20
        DEFAULT_MUTATION_RATE = 0.50
        DEFAULT_NUMBER_OF_GENERATIONS = 2
        DEFAULT_POPULATION_SIZE = 4
        DEFAULT_FITNESS_FUNCTION = "As"

		DEFAULT_INITIAL_POPULATION_FILE = "tests" + File::SEPARATOR + "testset.zip"
#        DEFAULT_IDA_DUMP = "disassemblies/"
#        DEFAULT_INITIAL_POPULATION = "tests/testset.zip"
#        MAX_FILE_SIZE = 2097152

		# Generate the YAML configuration file for Simple Genetic Algorithm Fuzzer
		def self.generate_config()
			simpleGAConfig = Hash.new()
			simpleGAConfig['Crossover Rate'] = 		DEFAULT_CROSSOVER_RATE 
			simpleGAConfig['Mutation Rate'] = 		DEFAULT_MUTATION_RATE
			simpleGAConfig['Maximum Generations'] = DEFAULT_NUMBER_OF_GENERATIONS 
			simpleGAConfig['Population Size'] = 	DEFAULT_POPULATION_SIZE 
			simpleGAConfig['Fitness Function'] = 	DEFAULT_FITNESS_FUNCTION	
			simpleGAConfig['Initial Population'] =  DEFAULT_INITIAL_POPULATION_FILE
			YAML::dump(simpleGAConfig)
		end

		# Initialize SimpleGeneticAlgorithm fuzzer and the generic fuzzer class
		def initialize(mambaConfig)
			super(mambaConfig)
			@simpleGAConfig = read_fuzzer_config(self.to_s())
			
			#
			# Print configuration to a log file
			#
			dump_config(@simpleGAConfig)

			#
			# Seed the initial population
			#
			@population = Population.new()
			@testSetMappings = Hash.new()
			seed()
		end

		# Run the fuzzing job
		def fuzz()
			@simpleGAConfig['Maximum Generations'].times do |generationNumber|
				nextGenerationNumber = generationNumber + 1
				@simpleGAConfig['Population Size'].times do |chromosomeID|
					@logger.info("Looping: #{generationNumber}/#{chromosomeID}")
					fitness = rand(25).to_s()
					@population.push(Chromosome.new(chromosomeID, fitness))
				end
				statistics()
				# Only evolve a new generation if needed
				evolve(nextGenerationNumber) unless (nextGenerationNumber) == @simpleGAConfig['Maximum Generations']
			end
		end

		private

		# Evolve a new generation and clear the current one
		def evolve(nextGenerationNumber)
			prepare_storage(nextGenerationNumber)
			0.step(@simpleGAConfig['Population Size']-1, 2) do |childID|
				parents, children = compose_filenames(nextGenerationNumber, childID)

				@logger.info("=================CHILDREN===============")
				@logger.info("Evolving: #{nextGenerationNumber}")
				@logger.info(parents)
				@logger.info(children)
				@logger.info("========================================")

				crossover(parents, children)
#				mutate(children)

				#
				# Clean up the parents
				#
#				parents.each { |parent| parent.close()}
#				children.each { |child| parent.close()}
				parents.clear()
				children.clear()
			end
			@population.clear()
		end

		# Function to compose new filenames for children of the next generation
		# @param [Fixnum] The next generation number
		# @param [Fixnum] The current child number being generated
		# @returns [Array, Array] 
		def compose_filenames(nextGenerationNumber, childID)
			parents = Array.new()
			children = Array.new()

			2.times do
				parents << "tests" + File::SEPARATOR + "#{nextGenerationNumber - 1}" + File::SEPARATOR + @testSetMappings[@population.roulette().id] 
			end

			2.times do |iter| 
				id = childID + iter
				children << "tests" + File::SEPARATOR + "#{nextGenerationNumber}" + File::SEPARATOR + "#{id}." + parents[iter].split(".")[-1] 
				@testSetMappings[childID + iter] = children[iter] 
			end

			return [parents, children]
		end

		# Single point crossover of two parent chromosomes
		# @param [Array] Array of parent filenames 
		# @param [Array] Array of children filenames 
		def crossover(parents, children)

			if(rand() <= @simpleGAConfig['Crossover Rate']) then

			else
				2.times do |iter|
					@logger.info("Copying: #{parents[iter]} to #{children[iter]}")
					FileUtils.cp(parents[iter], children[iter]) 
				end
			end
		end

		# Mutate a chromosome
		def mutate(children)
			@logger.info("Mutate")
		end

		def elitism()

		end

		# Make the next test case directory
		def prepare_storage(nextGenerationNumber)
           if !File.directory?("tests" + File::SEPARATOR + "#{nextGenerationNumber}") then
                FileUtils.mkdir_p("tests" + File::SEPARATOR + "#{nextGenerationNumber}")
            end
		end

		# Seeds the initial population by unzipping the test cases
		def seed()
			prepare_storage(0)			
			chromosomeNumber = 0
			testSetMapping = File.open("tests" + File::SEPARATOR + "test_set_map.txt", "w+")
			Zip::ZipFile.open(@simpleGAConfig['Initial Population']) do |zipfile|
				zipfile.each do |entry|
					if(entry.directory?) then
						@logger.info("#{entry.name} is a directory!")
						testSetMapping.printf("%-50.50s: skipped\n", entry.name)
						next
					else
						testSetMapping.printf("%-50.50s: #{chromosomeNumber}\n", entry.name)

						#
						# Write the zipped file data
						#
						@testSetMappings[chromosomeNumber] = "#{chromosomeNumber}#{File.extname(entry.name)}"
						File.open("tests" + File::SEPARATOR + "0" + File::SEPARATOR + "#{@testSetMappings[chromosomeNumber]}", "w+") do |newTestCase|
							newTestCase.write(zipfile.read(entry.name))
						end
						chromosomeNumber += 1
					end
				end
			end
			testSetMapping.close()

			#
			# Error check number of chromosomes equal configuration
			#
			if(chromosomeNumber != @simpleGAConfig['Population Size']) then
				@logger.fatal("Valid Chromosomes in zip file (#{chromosomeNumber} does not equal configured population size #{@simpleGAConfig['Population Size']}!")
				exit(1)
			end
		end

		# Calculate and log interesting population statistics
		def statistics()
			@logger.info("Total Generation Fitness: #{@population.fitness.to_s('F')}")
			@logger.info("Average Chromosome Fitness: #{(@population.fitness/@population.size()).to_s('F')}")
			@logger.info("Fittest Member: #{@population.max()}")
		end
	end
end
