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

class McpInstrumentationTest < ActionDispatch::IntegrationTest
  def call_tool
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: {
        name: "list_records", arguments: { resource: "mcp_instrumentation_widget" }
      } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }
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
end
