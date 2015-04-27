namespace :blueprint do

  @debug = false

  desc 'Generate a Conceptual Model diagram for the current Rails project'
  task :cm, [:options] => :environment do |t, args|
    # Rails.application.eager_load!

    # set the debug flag
    @debug = args[:options] == 'debug'

    # we store the detected model in a hash - which we later serialize to PogoScript
    model = { }

    # for debugging purposes
    step_count = 1

    # get the configured app name
    app_name = Dir.pwd.split('/').last.capitalize
    # app_name = Rails.application.class.parent_name

    print_debug step_count, "Application name is " + app_name
    step_count += 1

    unless Dir.exist?(Dir.pwd + '/app/models')
      print_debug step_count, 'Could not find models directory. Stopping analysis.'
      return 0
    end

    Dir.chdir(Dir.pwd + '/app/models') do

      # list all files in the directory
      Dir.foreach('.') { |f|

        # only deal with files that have a '.rb' extension
        if File.extname(f) == '.rb'
          # puts "Found: #{f}"

          # process each file
          File.open(f) do |m|
            concept_name = nil

            # process each line of the file
            m.each_line do |line|

              # search for the class declaration line
              clazz, super_clazz = line.match(/class ([^<]*) < (.*)/).try(:captures)

              # if we find a class declaration line, add the new concept to the model
              unless clazz.nil?
                # puts "Parsed: #{clazz} : #{super_clazz}"
                concept_name = clazz.pluralize

                # add the concept to the model hash
                model[concept_name] = [ ]

                print_debug step_count, "Adding concept " + concept_name
                step_count += 1

                unless super_clazz == 'ActiveRecord::Base'
                  is_a_name = super_clazz.singularize

                  # add the node relationship to the concept
                  model[concept_name].push({ :type => 'is a', :name => is_a_name })

                  print_debug step_count, "Concept " + concept_name + " is a " + is_a_name
                  step_count += 1
                end
              end

              # search for a 'has_one' or 'belongs_to' declaration
              a, has_one_clazz = line.match(/(has_one|belongs_to) :([^,]+)/).try(:captures)
              unless has_one_clazz.nil?
                has_one_name = has_one_clazz.capitalize.singularize.strip

                # add the node relationship to the concept
                model[concept_name].push({ :type => 'has one', :name => has_one_name })

                print_debug step_count, "Concept " + concept_name + " has one " + has_one_name
                step_count += 1
              end

              # search for a 'has_many' declaration
              b, has_many_clazz = line.match(/(has_many) :([^,]+)/).try(:captures)
              unless has_many_clazz.nil?
                has_many_name = has_many_clazz.capitalize.pluralize.strip

                # add the node relationship to the concept
                model[concept_name].push({ :type => 'has many', :name => has_many_name })

                print_debug step_count, "Concept " + concept_name + " has one " + has_many_name
                step_count += 1
              end

              # search for a 'has_many' declaration
              c, habtm_clazz = line.match(/(has_and_belongs_to_many) :([^,]+)/).try(:captures)
              unless habtm_clazz.nil?
                # this is a many-to-many, so we add two 'has many' relationships (one of each side)
                habtm_name = habtm_clazz.capitalize.pluralize.strip

                # add the first side of the 'has many' if it does not already exist
                if model[concept_name].find { |v| v[:type] == 'has many' && v[:name] == habtm_name }.nil?
                  model[concept_name].push({ :type => 'has many', :name => habtm_name })
                end

                # if the model hash doesn't have any entry for the many side of the relationship, create it
                if model[habtm_name].nil?
                  model[habtm_name] = [ ]
                end

                # add the second side of the 'has many' if it does not already exist
                if model[habtm_name].find { |v| v[:type] == 'has many' && v[:name] == concept_name }.nil?
                  model[habtm_name].push({ :type => 'has many', :name => concept_name })
                end

                print_debug step_count, "Concept " + concept_name + " has many-to-many with " + habtm_name
                step_count += 1
              end

            end
          end
        end
      }
    end

    # now generate the PogoScript
    pogo = "conceptual model for \"" + app_name + "\""
    model.each { |name, relationships|
      pogo << "\n concept \"" + name + "\"\n"

      relationships.each { |r|
        case r[:type]
          when 'is a'
            pogo << "  is a \"" + r[:name] + "\"\n"
          when 'has one'
            pogo << "  has one \"" + r[:name] + "\"\n"
          when 'has many'
            pogo << "  has many \"" + r[:name] + "\"\n"
          else
            # TODO implement
        end
      }
    }

    # output the result
    puts ''
    puts 'Navigate to the link below and paste the provided script into the editor'
    puts ''
    puts '        http://anaxim.io/scratchpad/'
    puts ''
    puts '~~~~'
    puts pogo
    puts '~~~~'
    puts ''
    puts ''
  end

  desc 'Alias for the \'cm\' task'
  task :conceptualise => :cm do
  end

  desc 'Alias for the \'cm\' task'
  task :conceptualize => :cm do
  end

  private

    def self.print_debug(step_count, str)
      if @debug
        puts "#{step_count}. " + str
      end
    end

end