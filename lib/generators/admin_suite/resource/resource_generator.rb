# frozen_string_literal: true

require "rails/generators"

module AdminSuite
  module Generators
    class ResourceGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :model_name, type: :string, required: true, desc: "ActiveRecord model name (e.g. User)"

      class_option :portal, type: :string, default: "ops", desc: "Portal key (e.g. ops, ai, assistant)"
      class_option :section, type: :string, default: "general", desc: "Sidebar section key"
      class_option :output_dir, type: :string, default: "app/admin/resources", desc: "Where to write the resource file"

      def create_resource_definition
        @model_class_name = model_name.camelize
        @resource_class_name = "#{@model_class_name}Resource"
        @portal = options[:portal].to_s
        @section = options[:section].to_s

        klass = safe_constantize(@model_class_name)
        @columns = build_columns(klass)
        @searchable = build_searchable(klass)
        @form_fields = build_form_fields(klass)

        template "resource.rb.tt", File.join(options[:output_dir], "#{@model_class_name.underscore}_resource.rb")
      end

      private

      def safe_constantize(name)
        name.constantize
      rescue NameError
        nil
      end

      def build_columns(klass)
        return [] unless klass&.respond_to?(:columns_hash)

        keys = klass.columns_hash.keys
        preferred = %w[id name title email email_address status active created_at updated_at]
        chosen = (preferred & keys)
        chosen = (chosen + (keys - chosen)).uniq
        chosen.take(6).map(&:to_sym)
      end

      def build_searchable(klass)
        return [] unless klass&.respond_to?(:columns_hash)

        stringish = klass.columns.select { |c| %i[string text].include?(c.type) }.map(&:name)
        preferred = %w[name title email email_address]
        (preferred & stringish).presence || stringish.take(3)
      end

      def build_form_fields(klass)
        return [] unless klass&.respond_to?(:columns)

        enums = klass.respond_to?(:defined_enums) ? klass.defined_enums : {}

        klass.columns.reject { |c| %w[id created_at updated_at].include?(c.name) }.map do |c|
          name = c.name
          if enums.key?(name)
            { name: name, type: :select, enum: enums[name].keys }
          else
            type =
              case c.type
              when :boolean then :toggle
              when :text then :textarea
              when :json, :jsonb then :json
              when :datetime, :timestamp then :datetime
              when :date then :date
              when :integer, :bigint, :float, :decimal then :number
              else
                :text
              end
            { name: name, type: type }
          end
        end
      end
    end
  end
end
