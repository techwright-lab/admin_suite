# frozen_string_literal: true

require "test_helper"

module McpListRecordsFixtures
  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name, :secret_token

    def initialize(id: 1, name: "Widget", secret_token: "sh-hh")
      @id = id
      @name = name
      @secret_token = secret_token
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([new])
  end
end

module Admin
  module Resources
    class McpListRecordsWidgetResource < Admin::Base::Resource
      model McpListRecordsFixtures::Widget
      portal :ops
      section :observability
      index do
        columns do
          column :id
          column :name
        end
      end
    end
  end
end

class McpListRecordsTest < McpIntegrationTest
  def call_tool(name, arguments)
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
    JSON.parse(response.body)
  end

  test "returns rows limited to declared columns" do
    result = with_authorize(->(**) { true }) do
      call_tool("list_records", { resource: "mcp_list_records_widget" })
    end

    refute result.dig("result", "isError"), result.inspect
    assert_match(/Widget/, result.to_s)
    refute_match(/sh-hh/, result.to_s)
  end

  test "clamps per_page to the configured maximum and says so" do
    result = with_authorize(->(**) { true }) do
      call_tool("list_records", { resource: "mcp_list_records_widget", per_page: 5000 })
    end

    payload = JSON.parse(result.dig("result", "content", 0, "text"))
    assert_equal 100, payload.fetch("applied_per_page")
  end

  test "an unknown resource and a denied resource return identical errors" do
    unknown = with_authorize(->(**) { true }) do
      call_tool("list_records", { resource: "no_such_thing" })
    end
    denied = with_authorize(->(**) { false }) do
      call_tool("list_records", { resource: "mcp_list_records_widget" })
    end

    assert_equal unknown.dig("result", "content"), denied.dig("result", "content"),
      "an existence oracle: an unknown resource must be indistinguishable from a denied one"
  end
end
