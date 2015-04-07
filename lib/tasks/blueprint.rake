namespace :blueprint do

  @debug = false

  desc 'Generate a Conceptual Model diagram for the current Rails project'
  task :cm, [:options] => :environment do |t, args|
    Rails.application.eager_load!

    # set the debug flag
    @debug = args[:options] == 'debug'

    # we store the detected model in a hash - which we later serialize to PogoScript
    model = { }

    # for debugging purposes
    step_count = 1

    # get the configured app name
    app_name = Rails.application.class.parent_name

    print_debug step_count, "Generating conceptual model PogoScript for " + app_name
    step_count += 1

    concepts = ActiveRecord::Base.descendants
    concepts.each { |m|
      next if m.name.starts_with?'HABTM' # we skip Rails 'special' HABTM model classes

      concept_name = humanise(m.name)

      # add the concept to the model hash
      model[concept_name] = [ ]

      print_debug step_count, "Adding concept " + concept_name
      step_count += 1

      unless m.superclass.to_s == 'ActiveRecord::Base'
        is_a_name = humanise(m.superclass.to_s.singularize.capitalize)

        # add the node relationship to the concept
        model[concept_name].push({ :type => 'is a', :name => is_a_name })

        print_debug step_count, "Concept " + concept_name + " is a " + is_a_name
        step_count += 1
      end

      associations = m.reflect_on_all_associations
      associations.each { |a|

        # TODO this is an OK solution but has some shortcomings - we need to figure out how to get the actual
        # TODO associated model name (not the macro name which we then singularize and capitalize)

        case a.macro
          when :belongs_to, :has_one
            has_one_name = humanise(a.name.to_s.singularize.capitalize)

            # add the node relationship to the concept
            model[concept_name].push({ :type => 'has one', :name => has_one_name })

            print_debug step_count, "Concept " + concept_name + " has one " + has_one_name
            step_count += 1

          when :has_many
            has_many_name = humanise(a.name.to_s.singularize.capitalize)

            # add the node relationship to the concept
            model[concept_name].push({ :type => 'has many', :name => has_many_name })

            print_debug step_count, "Concept " + concept_name + " has one " + has_many_name
            step_count += 1

          when :has_and_belongs_to_many
            # this is a many-to-many, so we add two 'has many' relationships (one of each side)
            has_many_name = humanise(a.name.to_s.singularize.capitalize)

            # add the first side of the 'has many' if it does not already exist
            if model[concept_name].find { |v| v[:type] == 'has many' && v[:name] == has_many_name }.nil?
              model[concept_name].push({ :type => 'has many', :name => has_many_name })
            end

            # if the model hash doesn't have any entry for the many side of the relationship, create it
            if model[has_many_name].nil?
              model[has_many_name] = [ ]
            end

            # add the second side of the 'has many' if it does not already exist
            if model[has_many_name].find { |v| v[:type] == 'has many' && v[:name] == concept_name }.nil?
              model[has_many_name].push({ :type => 'has many', :name => concept_name })
            end

            print_debug step_count, "Concept " + concept_name + " has many-to-many with " + has_many_name
            step_count += 1

          else
            print_debug step_count, "Did not recognise macro type: " + a.macro.to_s
            step_count += 1

        end
      }
    }

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
    puts '        http://blooming-waters-9183.herokuapp.com/scratchpad/'
    puts ''
    puts '==== * START * ===='
    puts pogo
    puts '==== * END * ===='
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

    def self.humanise(str)
      # this block applies a naming clean-up by camel-casing any words after an underscore (e.g.: Invited_by => InvitedBy)

      tokens = str.scan(/[_]+[\w]/)
      unless tokens.empty?
        tokens.each { |t|
          str[t]= t[-1, 1].capitalize
        }
      end

      str
    end

    def self.print_debug(step_count, str)
      if @debug
        puts "#{step_count}. " + str
      end
    end

end