# frozen_string_literal: true

require "test_helper"

module McpGetRecordFixtures
  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name, :secret_token

    def initialize(id: 1, name: "Widget", secret_token: "sh-hh")
      @id = id
      @name = name
      @secret_token = secret_token
    end

    def self.find_by(id:)
      new if id.to_s == "1"
    end
  end
end

module Admin
  module Resources
    class McpGetRecordWidgetResource < Admin::Base::Resource
      model McpGetRecordFixtures::Widget
      portal :ops
      section :observability
      show { panel :identity, fields: %i[id name] }
    end
  end
end

class McpGetRecordTest < ActionDispatch::IntegrationTest
  def call_tool(arguments)
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "get_record", arguments: arguments } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }
    JSON.parse(response.body)
  end

  test "returns one record using only the show field set" do
    result = with_authorize(->(**) { true }) do
      call_tool(resource: "mcp_get_record_widget", id: "1")
    end

    refute result.dig("result", "isError"), result.inspect
    assert_match(/Widget/, result.to_s)
    refute_match(/sh-hh/, result.to_s)
  end

  test "a missing id is indistinguishable from a denied read" do
    missing = with_authorize(->(**) { true }) do
      call_tool(resource: "mcp_get_record_widget", id: "999999")
    end
    denied = with_authorize(->(**) { false }) do
      call_tool(resource: "mcp_get_record_widget", id: "1")
    end

    assert_equal missing.dig("result", "content"), denied.dig("result", "content")
  end
end
