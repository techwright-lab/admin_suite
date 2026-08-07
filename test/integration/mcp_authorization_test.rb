# frozen_string_literal: true

require "test_helper"

module McpAuthorizationFixtures
  class Widget
    extend ActiveModel::Naming

    def self.all = ReadOnlyResourceFixtures::Relation.new([])
  end
end

module Admin
  module Resources
    class McpAuthorizationWidgetResource < Admin::Base::Resource
      model McpAuthorizationFixtures::Widget
      portal :ops
      section :observability
      index { columns { column :name } }
    end

    class McpAuthorizationDisabledResource < Admin::Base::Resource
      model McpAuthorizationFixtures::Widget
      portal :ops
      section :observability

      def self.mcp_enabled? = false
    end
  end
end

class McpAuthorizationTest < ActionDispatch::IntegrationTest
  def rpc(method, params = {})
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }
    JSON.parse(response.body)
  end

  def call_tool(name, arguments = {})
    rpc("tools/call", { name: name, arguments: arguments })
  end

  test "a nil authorize hook advertises no tools" do
    with_authorize(nil) do
      assert_empty rpc("tools/list").dig("result", "tools")
    end
  end

  test "a nil authorize hook denies a direct call to every tool" do
    with_authorize(nil) do
      %w[describe_resources list_records get_record aggregate].each do |tool|
        result = call_tool(tool, { resource: "mcp_authorization_widget", id: "1" })

        assert result["error"], "#{tool} must deny when config.authorize is nil"
      end
    end
  end

  test "the authorize hook receives an mcp surface and a read action" do
    seen = []
    hook = lambda do |action:, record:, context:, **|
      seen << [action, context.surface, record]
      true
    end

    with_authorize(hook) do
      call_tool("list_records", { resource: "mcp_authorization_widget" })
    end

    assert_includes seen, [:read, :mcp, nil]
  end

  test "describe_resources omits resources the hook denies" do
    hook = ->(resource:, **) { resource.resource_name != "mcp_authorization_widget" }

    with_authorize(hook) do
      refute_match(/mcp_authorization_widget/, call_tool("describe_resources").to_s)
    end
  end

  test "an mcp-disabled resource is invisible and unreachable" do
    with_authorize(->(**) { true }) do
      refute_match(/mcp_authorization_disabled/, call_tool("describe_resources").to_s)
      assert call_tool("list_records", { resource: "mcp_authorization_disabled" }).dig("result", "isError")
    end
  end

  test "a raising authorize hook denies instead of returning a server error" do
    with_authorize(->(**) { raise "boom" }) do
      result = call_tool("list_records", { resource: "mcp_authorization_widget" })

      assert result.dig("result", "isError"), result.inspect
    end
  end
end
