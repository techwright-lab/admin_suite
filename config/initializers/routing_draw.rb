# frozen_string_literal: true

# Routing Draw Extension
#
# Enables splitting routes into separate files under config/routes/
# Usage in routes.rb:
#   draw :admin     # loads config/routes/admin.rb
#   draw :public    # loads config/routes/public.rb
#
# This keeps the main routes.rb clean and organized by domain.

module ActionDispatch
  module Routing
    class Mapper
      def draw(name)
        path = Rails.root.join("config", "routes", "#{name}.rb")
        unless path.exist?
          raise "Routes file not found: #{path}"
        end

        instance_eval(File.read(path), path.to_s)
      end
    end
  end
end

