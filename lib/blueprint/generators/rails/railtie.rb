require 'blueprint/generators/rails'
require 'rails'

module BlueprintGeneratorsRails
  class Railtie < Rails::Railtie
    railtie_name :blueprint_generators_rails

    rake_tasks do
      load "tasks/blueprint.rake"
    end
  end
end