# frozen_string_literal: true

require "test_helper"

module ReadOnlyResourceFixtures
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

    def self.where(id:)
      id.filter_map { |value| find(value) }
    end

    def to_param
      id.to_s
    end

    def attributes
      { "id" => id, "name" => name }
    end

    def self.ping_calls
      @ping_calls || 0
    end

    def self.ping_calls=(value)
      @ping_calls = value
    end

    def ping
      self.class.ping_calls += 1
      true
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

      actions do
        action :ping
        bulk_action :ping
      end
    end
  end
end

module WritableResourceFixtures
  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id: 1, name: "Writable widget")
      @id = id
      @name = name
    end

    def self.all
      ReadOnlyResourceFixtures::Relation.new([ new ])
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

    def self.where(id:)
      id.filter_map { |value| find(value) }
    end

    def self.ping_calls
      @ping_calls || 0
    end

    def self.ping_calls=(value)
      @ping_calls = value
    end

    def to_param
      id.to_s
    end

    def attributes
      { "id" => id, "name" => name }
    end

    def ping
      self.class.ping_calls += 1
      true
    end
  end
end

module Admin
  module Resources
    class WritableWidgetResource < Admin::Base::Resource
      model WritableResourceFixtures::Widget
      portal :ops
      section :observability

      index do
        columns do
          column :name
        end
      end

      actions do
        action :ping
        bulk_action :ping
      end
    end
  end
end

module AdminSuite
  class ReadOnlyResourceTest < ActionDispatch::IntegrationTest
    BASE_PATH = "/internal/admin_suite/ops/read_only_widgets"
    WRITABLE_PATH = "/internal/admin_suite/ops/writable_widgets"

    setup do
      ReadOnlyResourceFixtures::Widget.ping_calls = 0
      WritableResourceFixtures::Widget.ping_calls = 0
    end

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

    test "toggle endpoint is rejected on read_only resources" do
      post "#{BASE_PATH}/1/toggle", params: { field: "name" }
      assert_response :not_found
    end

    test "undeclared execute_action names respond 404" do
      post "#{BASE_PATH}/1/execute_action/nonexistent_action"
      assert_response :not_found
    end

    test "undeclared bulk_action names respond 404" do
      post "#{BASE_PATH}/bulk_action/nonexistent_bulk", params: { ids: ["1"] }
      assert_response :not_found
    end

    test "declared member actions are rejected on read_only resources" do
      post "#{BASE_PATH}/1/execute_action/ping"

      assert_response :not_found
      assert_equal 0, ReadOnlyResourceFixtures::Widget.ping_calls
    end

    test "declared bulk actions are rejected on read_only resources" do
      post "#{BASE_PATH}/bulk_action/ping", params: { ids: [ "1" ] }

      assert_response :not_found
      assert_equal 0, ReadOnlyResourceFixtures::Widget.ping_calls
    end

    test "declared member actions still execute on writable resources" do
      post "#{WRITABLE_PATH}/1/execute_action/ping"

      assert_redirected_to "#{WRITABLE_PATH}/1"
      assert_equal 1, WritableResourceFixtures::Widget.ping_calls
    end

    test "declared bulk actions still execute on writable resources" do
      post "#{WRITABLE_PATH}/bulk_action/ping", params: { ids: [ "1" ] }

      assert_redirected_to WRITABLE_PATH
      follow_redirect!
      assert_includes response.body, "Successfully processed 1 records"
      assert_equal 1, WritableResourceFixtures::Widget.ping_calls
    end
  end
end
