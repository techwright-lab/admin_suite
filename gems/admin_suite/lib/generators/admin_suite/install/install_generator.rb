# frozen_string_literal: true

require "rails/generators"

module AdminSuite
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs AdminSuite initializer and mounts the engine."

      class_option :mount_path, type: :string, default: "/internal/admin", desc: "Path to mount AdminSuite::Engine"

      def create_initializer
        template "admin_suite.rb", "config/initializers/admin_suite.rb"
      end

      def mount_engine
        route %(mount AdminSuite::Engine => "#{options[:mount_path]}")
      end
    end
  end
end
