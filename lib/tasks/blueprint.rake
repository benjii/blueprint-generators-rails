namespace :blueprint do

  desc 'Generate a Conceptual Model diagram for the current Rails project'
  task :cm => :environment do
    Rails.application.eager_load!

    pogo = "conceptual model for \"" + Rails.application.class.parent_name + "\""

    models = ActiveRecord::Base.descendants
    models.each { |m|
      pogo << "\n concept \"" + humanise(m.name) + "\"\n"

      associations = m.reflect_on_all_associations
      associations.each { |a|

        # TODO this is an OK solution but has some shortcomings - we need to figure out how to get the actual
        # TODO associated model name (not the macro name which we then singularize and capitalize)

        case a.macro
          when :belongs_to, :has_one
            pogo << "  has one \"" + humanise(a.name.to_s.singularize.capitalize) + "\"\n"
          when :has_many
            pogo << "  has many \"" + humanise(a.name.to_s.singularize.capitalize) + "\"\n"
          else
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