# frozen_string_literal: true

require "test_helper"

module McpReleaseFixtures
  Record = Struct.new(:id, :state)

  class Relation
    include Enumerable
    def initialize(rows) = @rows = rows
    def each(&block) = @rows.each(&block)
    def count = @rows.size
    def offset(n) = self.class.new(@rows.drop(n))
    def limit(n) = self.class.new(@rows.first(n))
    def where(conditions)
      self.class.new(@rows.select { |row| conditions.all? { |key, value| row.public_send(key) == value } })
    end
  end

  class Widget
    extend ActiveModel::Naming
    def self.all = Relation.new([Record.new(1, "open"), Record.new(2, "closed")])
    def self.find_by(id:) = all.find { |row| row.id.to_s == id.to_s }
  end
end

module Admin
  module Resources
    class McpReleaseWidgetResource < Admin::Base::Resource
      model McpReleaseFixtures::Widget
      portal :ops
      section :observability
      index do
        paginate 500
        columns { column :id }
        filters { filter :state, type: :select }
      end
      show { panel :identity, fields: %i[id state] }
    end
  end
end

class McpReleaseTest < ActionDispatch::IntegrationTest
  setup do
    @previous_actor = AdminSuite.config.current_actor
    AdminSuite.config.current_actor = ->(_) { "release-test-operator" }
  end

  teardown { AdminSuite.config.current_actor = @previous_actor }

  def call_tool(name, **arguments)
    post "/internal/admin_suite/mcp", params: {
      jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments }
    }.to_json, headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
    JSON.parse(response.body)
  end

  test "JSON filters affect both records and aggregates" do
    with_authorize(->(**) { true }) do
      result = call_tool("list_records", resource: "mcp_release_widget", filters: { state: "open" })
      payload = JSON.parse(result.dig("result", "content", 0, "text"))
      assert_equal [1], payload.fetch("rows").map { |row| row.fetch("id") }
      assert_equal 100, payload.fetch("applied_per_page")
      result = call_tool("aggregate", resource: "mcp_release_widget", filters: { state: "closed" })
      assert_equal 1, JSON.parse(result.dig("result", "content", 0, "text")).fetch("count")
    end
  end

  test "an anonymous MCP request is rejected even in the development escape hatch" do
    AdminSuite.config.current_actor = nil
    with_authorize(->(**) { true }) do
      post "/internal/admin_suite/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
        headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
      assert_response :unauthorized
    end
  end

  test "get_record checks record policy and passes the HTTP request to authorization" do
    seen_requests = []
    policy = ->(record:, context:, **) do
      seen_requests << context.request
      record.nil? || record.id != 1
    end
    with_authorize(policy) do
      denied = call_tool("get_record", resource: "mcp_release_widget", id: "1")
      missing = call_tool("get_record", resource: "mcp_release_widget", id: "999")
      assert denied.dig("result", "isError")
      assert_equal missing.dig("result", "content"), denied.dig("result", "content")
      assert seen_requests.all? { |request| request.is_a?(ActionDispatch::Request) }
    end
  end

  test "MCP rejects foreign origins while allowing same-origin and headless clients" do
    with_authorize(->(**) { true }) do
      ["https://attacker.example", "null", ""].each do |origin|
        post "/internal/admin_suite/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream", "HTTP_ORIGIN" => origin }
        assert_response :forbidden
      end
      post "/internal/admin_suite/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
        headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream", "HTTP_ORIGIN" => "http://www.example.com" }
      assert_response :success
    end
  end

  test "the stateless transport accepts notifications and declines GET streams" do
    with_authorize(->(**) { true }) do
      post "/internal/admin_suite/mcp", params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
        headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
      assert_response :accepted
      assert_empty response.body
      get "/internal/admin_suite/mcp"
      assert_response :method_not_allowed
    end
  end

  test "forgery protection allows the JSON transport but rejects tokenless forms" do
    previous = AdminSuite::McpController.allow_forgery_protection
    AdminSuite::McpController.allow_forgery_protection = true
    with_authorize(->(**) { true }) do
      call_tool("list_records", resource: "mcp_release_widget")
      assert_response :success
      post "/internal/admin_suite/mcp", params: { method: "tools/list" }
      assert_response :unprocessable_entity
    end
  ensure
    AdminSuite::McpController.allow_forgery_protection = previous
  end
end
