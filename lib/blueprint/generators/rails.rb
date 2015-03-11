require "blueprint/generators/rails/version"
require "rails"

module Blueprint
  module Generators
    module Rails
      # load the rake tasks - this is all that this gem does
      load "tasks/blueprint.rake"
    end
  end
end
