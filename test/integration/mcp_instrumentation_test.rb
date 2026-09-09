# frozen_string_literal: true

require "test_helper"

module McpInstrumentationFixtures
  class Widget
    extend ActiveModel::Naming

    def self.all = ReadOnlyResourceFixtures::Relation.new([])
  end
end

module Admin
  module Resources
    class McpInstrumentationWidgetResource < Admin::Base::Resource
      model McpInstrumentationFixtures::Widget
      portal :ops
      section :observability
      index { columns { column :name } }
    end
  end
end

class McpInstrumentationTest < McpIntegrationTest
  AuditActor = Struct.new(:id)
  def call_tool(arguments = { resource: "mcp_instrumentation_widget" })
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: {
        name: "list_records", arguments: arguments
      } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
  end

  test "every tool call emits one complete event whether allowed or denied" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("admin_suite.mcp.tool_call") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args).payload
    end

    with_authorize(->(**) { true }) { call_tool }
    with_authorize(nil) { AdminSuite::Mcp::Tools::ListRecords.call(
      resource: "mcp_instrumentation_widget", server_context: { actor: nil }
    ) }

    assert_equal [true, false], events.map { |event| event[:allowed] }
    assert events.all? { |event| event[:tool] == "list_records" }
    assert events.all? { |event| event[:action] == :read }
    assert events.all? { |event| event[:duration_ms].is_a?(Numeric) }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "a raise inside authorize_resource! is not logged as an authorized read" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("admin_suite.mcp.tool_call") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args).payload
    end

    AdminSuite::Mcp::Authorization.stub(:authorize_resource!, proc { raise "boom" }) do
      AdminSuite::Mcp::Tools::ListRecords.call(
        resource: "mcp_instrumentation_widget",
        server_context: { actor: "x" }
      )
    end

    assert_equal false, events.last[:allowed]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "audit metadata identifies the operator and distinguishes tool failures" do
    actor = AuditActor.new(42)
    request = Struct.new(:request_id).new("audit-request-123")
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("admin_suite.mcp.tool_call") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args).payload
    end

    AdminSuite::Mcp.instrument(tool: "list_records", actor: actor, request: request) do
      [MCP::Tool::Response.new([{ type: "text", text: "failed" }], error: true), nil, true]
    end

    assert_equal "42", events.first.fetch(:actor_id)
    assert_equal actor.class.name, events.first.fetch(:actor_type)
    assert_equal "audit-request-123", events.first.fetch(:request_id)
    assert_equal true, events.first.fetch(:error)
    assert_equal true, events.first.fetch(:allowed)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "the audit event carries the applied filter set" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("admin_suite.mcp.tool_call") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args).payload
    end

    with_authorize(->(**) { true }) do
      call_tool(resource: "mcp_instrumentation_widget", q: "alpha", filters: { state: "open" })
    end

    assert_equal "alpha", events.last.fetch(:q)
    assert_equal({ state: "open" }, events.last.fetch(:filters))
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
