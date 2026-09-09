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
      actions do
        action :approve
        bulk_action :archive
      end
    end
  end
end

class McpEndpointTest < McpIntegrationTest
  def rpc(method, params = {}, id: 1)
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: id, method: method, params: params }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
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

  test "describe_resources includes portal, section, and declared actions" do
    with_authorize(->(**) { true }) do
      result = rpc("tools/call", { name: "describe_resources", arguments: {} })
      payload = JSON.parse(result.dig("result", "content", 0, "text"))
      widget = payload.find { |resource| resource["name"] == "mcp_endpoint_widget" }

      assert_equal "ops", widget.fetch("portal")
      assert_equal "observability", widget.fetch("section")
      assert_includes widget.fetch("actions"), { "name" => "approve", "kind" => "member" }
      assert_includes widget.fetch("actions"), { "name" => "archive", "kind" => "bulk" }
    end
  end

  test "describe_resources returns a generic error without the raised message" do
    with_authorize(->(**) { true }) do
      AdminSuite::Mcp::Tools::DescribeResources.stub(:describe, proc { raise "SECRET-/db/password-detail" }) do
        result = rpc("tools/call", { name: "describe_resources", arguments: {} })

        refute result["error"], result.inspect
        assert result.dig("result", "isError")
        body = result.to_s
        assert_match(/describe_resources failed/, body)
        refute_match(/SECRET-\/db\/password-detail/, body)
      end
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
