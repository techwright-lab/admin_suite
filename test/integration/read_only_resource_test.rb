# frozen_string_literal: true

require "test_helper"

# The dummy app is intentionally database-free, while the generic controller
# supports Active Record hosts. Supply only the exception type its lookup path
# rescues so show-page behavior can be exercised with an in-memory fixture.
unless defined?(ActiveRecord::RecordNotFound)
  module ActiveRecord
    class RecordNotFound < StandardError; end
  end
end

module TurboFrameTestHelper
  def turbo_frame_tag(name, **options, &block)
    content_tag(:turbo_frame, capture(&block), id: name, **options)
  end
end

ActionView::Base.include(TurboFrameTestHelper)

module ReadOnlyResourceFixtures
  class Relation
    include Enumerable

    def initialize(records)
      @records = records
    end

    def each(&block)
      @records.each(&block)
    end

    def count(*)
      @records.count
    end

    def offset(*)
      self
    end

    def limit(*)
      self
    end
  end

  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id: 1, name: "Observed widget")
      @id = id
      @name = name
    end

    def self.all
      Relation.new([ new ])
    end

    def self.column_names
      %w[id name]
    end

    def self.primary_key
      "id"
    end

    def self.columns_hash
      { "id" => Struct.new(:type).new(:integer) }
    end

    def self.find(id)
      raise ActiveRecord::RecordNotFound unless id.to_s == "1"

      new
    end

    def to_param
      id.to_s
    end

    def attributes
      { "id" => id, "name" => name }
    end
  end
end

module Admin
  module Resources
    class ReadOnlyWidgetResource < Admin::Base::Resource
      model ReadOnlyResourceFixtures::Widget
      portal :ops
      section :observability
      read_only

      index do
        columns do
          column :name
        end
      end
    end
  end
end

module AdminSuite
  class ReadOnlyResourceTest < ActionDispatch::IntegrationTest
    BASE_PATH = "/internal/admin_suite/ops/read_only_widgets"

    test "direct built in mutation endpoints are rejected" do
      get "#{BASE_PATH}/new"
      assert_response :not_found

      post BASE_PATH, params: { read_only_resource_fixtures_widget: { name: "changed" } }
      assert_response :not_found

      get "#{BASE_PATH}/1/edit"
      assert_response :not_found

      patch "#{BASE_PATH}/1", params: { read_only_resource_fixtures_widget: { name: "changed" } }
      assert_response :not_found

      delete "#{BASE_PATH}/1"
      assert_response :not_found
    end

    test "index hides create and edit controls" do
      get BASE_PATH

      assert_response :success
      assert_includes response.body, "Observed widget"
      refute_includes response.body, "New Widget"
      refute_match(/>\s*Edit\s*</, response.body)
    end

    test "show mutation controls are conditional on write access" do
      template = AdminSuite::Engine.root.join("app/views/admin_suite/resources/show.html.erb").read

      assert_includes template, "has_edit_route = !resource_config.read_only?"
      assert_includes template, "has_destroy_route = !resource_config.read_only?"
    end
  end
end
