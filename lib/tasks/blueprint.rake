namespace :blueprint do

  @debug = false

  desc 'Generate Sequence diagrams for the current Rails project (requires use of semantic tags)'
  task :seq, :root_dir, :debug  do |t, args|

    root_dir = args[:root_dir] || '.'
    @debug = args[:debug]

    if @debug
      puts "Debug mode #{@debug}"
      puts "Root directory for analysis is: #{root_dir}"
    end

    # check that this is actually a Rails projects
    unless File.exist?(root_dir + '/Gemfile')
      puts 'No Gemfile found. Is this a Rails project?'
      next
    end

    # if we get here than all base sanity checks are passed

    # for debugging purposes
    step_count = 1

    model = { }

    # otherwise continue analysis
    Dir.chdir(root_dir) do
      # list all files in the directory - we scan everything (but maybe we shouldn't)
      Dir.glob('**/*.{rb,js,coffee}').each { |f|
        file = File.stat f

        if file.file?

          File.open(f).each do |line|

            # we are scanning for things like this:
            #   # @sequence[test, browser, up, foo bar]

            tag = line.match(/#[\s]*@sequence\[(.*)\]/).try(:captures).try(:first)

            if tag
              print_debug step_count, "Found sequence tag with values: '#{tag}'"
              step_count += 1

              name, lane, direction, action = tag.split(',').map(&:strip)

              model[name] ||= { }
              (model[name][:lanes] ||= [ ]) << lane
              (model[name][:movements] ||= [ ]) << { :direction => direction, :action => action }
            end
          end
        end
      }

      # now generate the PogoScript - there may be more than one
      pogos = [ ]

      model.each { |key, value|
        pogo = "sequence \"#{key}\" lanes \"#{value[:lanes].uniq.join(',')}\"\n"
        value[:movements].each { |m|
          case m[:direction]
            when 'up'
              pogo += " up \"#{m[:action]}\"\n"
            when 'down'
              pogo += " down \"#{m[:action]}\"\n"
            when 'fail down'
              pogo += " fail down if \"#{m[:action]}\"\n"
            else
              raise "Direction not recognised when generating PogoScript: #{m[:direction]}"
          end
        }

        pogos << pogo
      }

      puts ''
      puts 'Navigate to the link below and paste the provided script into the editor found at:'
      puts ''
      puts '        http://anaxim.io/scratchpad/'
      puts ''
      pogos.each { |pogo|
        puts '~~~~'
        puts pogo
        puts '~~~~'
      }
      puts ''
      puts ''

    end

  end

  desc 'Alias for the \'seq\' task'
  task :sequence => :seq do
  end

  desc 'Generate a Conceptual Model diagram for the current Rails project'
  task :cm, :root_dir, :debug  do |t, args|

    root_dir = args[:root_dir] || '.'
    @debug = args[:debug]

    if @debug
      puts "Debug mode #{@debug}"
      puts "Root directory for analysis is: #{root_dir}"
    end

    # check that this is actually a Rails projects
    unless File.exist?(root_dir + '/Gemfile')
      puts 'No Gemfile found. Is this a Rails project?'
      next
    end

    # if the config directory can't be found then stop
    unless Dir.exist?(root_dir + '/config')
      puts 'No config directory found. Is this a Rails project?'
      next
    end

    # if an application.rb file can't be found in the config directory then stop
    unless File.exist?(root_dir + '/config/application.rb')
      puts 'No application.rb found in config directory. Is this a Rails project?'
      next
    end

    # if the models directory can't be found then stop
    unless Dir.exist?(root_dir + '/app/models')
      puts 'No app/models directory found. Is this a Rails project?'
      next
    end

    # if we get here than all base sanity checks are passed

    # we store the detected model in a hash - which we later serialize to PogoScript
    model = { }

    # for debugging purposes
    step_count = 1

    # get the configured app name
    app_name = nil

    # otherwise find the application name
    Dir.chdir(root_dir + '/config') do
      File.open('application.rb') do |f|
        f.each_line do |line|
          m, app_name = line.match(/(module )(.*)/).try(:captures)
          unless app_name.nil?
            print_debug step_count, "Application name is #{app_name}"
            step_count += 1
            break
          end
        end
      end
    end

    # otherwise continue analysis
    Dir.chdir(root_dir + '/app/models') do

      # list all files in the directory
      Dir.glob('**/*.rb').each { |f|

        # process each file
        File.open(f) do |g|
          concept_name = nil

          # process each line of the file
          g.each_line do |line|

            # search for the class declaration line
            clazz, super_clazz = line.match(/class ([^<]*) < ([^,#\s]*[.]*)/).try(:captures)

            # if we find a class declaration line, add the new concept to the model
            unless clazz.nil?
              concept_name = clazz.pluralize

              # add the concept to the model hash
              model[concept_name] = [ ]

              print_debug step_count, "Adding concept " + concept_name
              step_count += 1

              unless super_clazz.strip == 'ActiveRecord::Base'
                is_a_name = super_clazz.singularize

                # add the node relationship to the concept
                model[concept_name].push({ :type => 'is a', :name => is_a_name })

                print_debug step_count, "Concept " + concept_name + " is a " + is_a_name
                step_count += 1
              end
            end

            # search for a 'has_one' or 'belongs_to' declaration
            a, has_one_clazz = line.match(/(has_one|belongs_to) :([^,#\s]+)/).try(:captures)
            unless has_one_clazz.nil?
              has_one_name = has_one_clazz.classify.singularize.strip

              # add the node relationship to the concept
              model[concept_name].push({ :type => 'has one', :name => has_one_name })

              print_debug step_count, "Concept " + concept_name + " has one " + has_one_name
              step_count += 1
            end

            # search for a 'has_many' declaration
            b, has_many_symbol = line.match(/(has_many) :([^,#\s]+)/).try(:captures)
            unless has_many_symbol.nil?
              has_many_name = has_many_symbol.classify.pluralize.strip

              # if this declaration has a class name then make sure that we use it in our model
              explicit_class_name = line.match(/class_name:[\s]*'(.*)'[,]?/).try(:captures)
              where_clause = line.match(/(where)/).try(:captures)

              # we behave in one of two ways here (just like Rails)
              # if there is an explicit class name defined then use that as the model name, otherwise use the has many symbol
              # also, in the case of an explicit class name being declared, look for a 'where' clause (if we find one then
              # use the has many symbole as the name of the subset that is being defined)

              # add the node relationship to the concept
              if explicit_class_name.nil? || explicit_class_name.empty?
                model[concept_name].push({ :type => 'has many', :name => has_many_name })
              else
                # puts explicit_class_name.inspect
                if where_clause.nil? || where_clause.empty?
                  model[concept_name].push({ :type => 'has many', :name => explicit_class_name.first.pluralize })
                else
                  model[concept_name].push({ :type => 'has many', :name => explicit_class_name.first.pluralize,
                                             :condition => has_many_symbol.capitalize.pluralize })
                end
              end

              print_debug step_count, "Concept #{concept_name} has one #{has_many_name}"
              step_count += 1
            end

            # search for a 'has_many' declaration
            c, habtm_clazz = line.match(/(has_and_belongs_to_many) : :([^,#\s]+)/).try(:captures)
            unless habtm_clazz.nil?
              # this is a many-to-many, so we add two 'has many' relationships (one of each side)
              habtm_name = habtm_clazz.classify.pluralize.strip

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

              print_debug step_count, "Concept #{concept_name} has many-to-many with #{habtm_name}"
              step_count += 1
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
            if r.has_key?(:condition) && !r[:condition].nil?
              pogo << "  has many \"" + r[:name] + "\" that are \"" + r[:condition] + "\"\n"
            else
              pogo << "  has many \"" + r[:name] + "\"\n"
            end
          else
            # TODO implement
        end
      }
    }

    # output the result
    puts ''
    puts 'Navigate to the link below and paste the provided script into the editor found at:'
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