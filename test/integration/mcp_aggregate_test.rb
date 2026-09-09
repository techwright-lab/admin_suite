# frozen_string_literal: true

require "test_helper"

module McpAggregateFixtures
  class Widget
    extend ActiveModel::Naming

    def self.all = ReadOnlyResourceFixtures::Relation.new([new, new])
  end
end

module Admin
  module Resources
    class McpAggregateWidgetResource < Admin::Base::Resource
      model McpAggregateFixtures::Widget
      portal :ops
      section :observability
      index do
        stats { stat :total, ->(scope) { scope.count } }
      end
    end
  end
end

class McpAggregateTest < McpIntegrationTest
  def call_tool(arguments)
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "aggregate", arguments: arguments } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
    JSON.parse(response.body)
  end

  test "returns a count and declared stats without records" do
    result = with_authorize(->(**) { true }) do
      call_tool(resource: "mcp_aggregate_widget")
    end

    payload = JSON.parse(result.dig("result", "content", 0, "text"))
    assert_equal 2, payload.fetch("count")
    assert_equal 2, payload.dig("stats", "total")
    refute payload.key?("rows"), "aggregate must never return records"
  end
end
