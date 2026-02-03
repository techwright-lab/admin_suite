# frozen_string_literal: true

require "rails/generators"

module AdminSuite
  module Generators
    class ScaffoldGenerator < Rails::Generators::Base
      argument :model_name, type: :string, required: true
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      class_option :portal, type: :string, default: "ops"
      class_option :section, type: :string, default: "general"

      def run_rails_scaffold
        Rails::Generators.invoke("scaffold", [ model_name, *attributes ], behavior: behavior)
      end

      def run_admin_suite_resource
        Rails::Generators.invoke(
          "admin_suite:resource",
          [ model_name ],
          portal: options[:portal],
          section: options[:section]
        )
      end
    end
  end
end
