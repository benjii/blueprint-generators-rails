namespace :blueprint do

  desc 'Generate a Conceptual Model diagram for the current Rails project'
  task :cm, [:options] => :environment do |t, args|
    Rails.application.eager_load!

    # for debugging purposes
    step_count = 1

    app_name = Rails.application.class.parent_name
    pogo = "conceptual model for \"" + app_name + "\""

    if args[:options] == 'debug'
      puts "#{step_count}. Generating conceptual model PogoScript for " + app_name
      step_count += 1
    end

    models = ActiveRecord::Base.descendants
    models.each { |m|

      concept_name = humanise(m.name)
      pogo << "\n concept \"" + concept_name + "\"\n"

      if args[:options] == 'debug'
        puts "#{step_count}. Adding concept " + concept_name
        step_count += 1
      end

      unless m.superclass.to_s == 'ActiveRecord::Base'
        is_a_name = humanise(m.superclass.to_s.singularize.capitalize)
        pogo << "  is a \"" + is_a_name + "\"\n"

        if args[:options] == 'debug'
          puts "#{step_count}. Concept " + concept_name + " is a " + is_a_name
          step_count += 1
        end
      end

      associations = m.reflect_on_all_associations
      associations.each { |a|

        # TODO this is an OK solution but has some shortcomings - we need to figure out how to get the actual
        # TODO associated model name (not the macro name which we then singularize and capitalize)

        case a.macro
          when :belongs_to, :has_one
            has_one_name = humanise(a.name.to_s.singularize.capitalize)
            pogo << "  has one \"" + has_one_name + "\"\n"

            if args[:options] == 'debug'
              puts "#{step_count}. Concept " + concept_name + " has one " + has_one_name
              step_count += 1
            end

          when :has_many
            has_many_name = humanise(a.name.to_s.singularize.capitalize)
            pogo << "  has many \"" + has_many_name + "\"\n"

            if args[:options] == 'debug'
              puts "#{step_count}. Concept " + concept_name + " has one " + has_many_name
              step_count += 1
            end

          else
            # TODO support other macro types and variants (i.e.: has_and_belongs_to_many, through, etc)

            if args[:options] == 'debug'
              puts "#{step_count}. Did not recognise macro type!"
              step_count += 1
            end

          # TODO error condition

        end
      }
    }

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

end