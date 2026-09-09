# frozen_string_literal: true

require "test_helper"

module McpEndpointFixtures
  class Widget
    extend ActiveModel::Naming
  end
end

module Admin
  module Resources
    class McpEndpointWidgetResource < Admin::Base::Resource
      model McpEndpointFixtures::Widget
      portal :ops
      section :observability
      index do
        columns { column :name }
      end
    end
  end
end

class McpEndpointTest < ActionDispatch::IntegrationTest
  def rpc(method, params = {}, id: 1)
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: id, method: method, params: params }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }
    JSON.parse(response.body)
  end

  test "tools/list advertises the read tools when an authorize hook permits" do
    with_authorize(->(**) { true }) do
      names = rpc("tools/list").dig("result", "tools").map { |tool| tool["name"] }

      assert_includes names, "describe_resources"
    end
  end

  test "describe_resources returns declared resources and their fields" do
    with_authorize(->(**) { true }) do
      result = rpc("tools/call", { name: "describe_resources", arguments: {} })

      refute result.dig("result", "isError"), result.inspect
      assert_match(/mcp_endpoint_widget/, result.to_s)
      assert_match(/name/, result.to_s)
    end
  end

  test "a nil authorize hook advertises no tools and denies direct calls" do
    with_authorize(nil) do
      assert_empty rpc("tools/list").dig("result", "tools")

      result = rpc("tools/call", { name: "describe_resources", arguments: {} })
      assert result["error"], result.inspect
    end
  end
end
