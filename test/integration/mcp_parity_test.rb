# frozen_string_literal: true

require "test_helper"

module McpParityFixtures
  class Relation
    include Enumerable

    def initialize(records, offset: 0)
      @records = records
      @offset = offset
    end

    def each(&block) = @records.each(&block)
    def count(*) = @records.size
    def offset(value) = self.class.new(@records, offset: value)
    def limit(value) = @records[@offset, value] || []

    def where(condition, search:)
      fields = condition.scan(/(\w+) ILIKE/).flatten
      term = search.delete("%").downcase
      self.class.new(@records.select do |record|
        fields.any? { |field| record.public_send(field).to_s.downcase.include?(term) }
      end)
    end

    def order(ordering)
      field, direction = ordering.first
      rows = @records.sort_by { |record| record.public_send(field).to_s }
      rows.reverse! if direction.to_sym == :desc
      self.class.new(rows)
    end
  end

  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end

    ROWS = [new(id: 1, name: "Zulu"), new(id: 2, name: "Alpha"), new(id: 3, name: "Bravo")].freeze

    def self.all = Relation.new(ROWS)
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def to_param = id.to_s
  end
end

module Admin
  module Resources
    class McpParityWidgetResource < Admin::Base::Resource
      model McpParityFixtures::Widget
      portal :ops
      section :observability
      index do
        searchable :name
        sortable :name, default: :name, direction: :asc
        columns do
          column :id
          column :name, sortable: true
        end
      end
    end
  end
end

class McpParityTest < McpIntegrationTest
  PATH = "/internal/admin_suite/ops/mcp_parity_widgets"

  def mcp_payload(tool, arguments)
    post "/internal/admin_suite/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: {
        name: tool, arguments: arguments
      } }.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json, text/event-stream" }
    rpc = JSON.parse(response.body)
    JSON.parse(rpc.dig("result", "content", 0, "text"))
  end

  test "list_records and the index return identical ids for one query" do
    with_authorize(->(**) { true }) do
      get PATH, params: { search: "alpha", sort: "name", direction: "asc" }
      assert_response :success
      ui_ids = css_select("tbody tr").map { |row| row["data-record-id"] }

      mcp_ids = mcp_payload("list_records", {
        resource: "mcp_parity_widget", q: "alpha", sort: "name", direction: "asc"
      }).fetch("rows").map { |row| row.fetch("id").to_s }

      assert_equal ui_ids, mcp_ids
    end
  end

  test "aggregate count matches the shared query's index total" do
    with_authorize(->(**) { true }) do
      get PATH, params: { search: "alpha" }
      ui_total = css_select("tbody tr").size

      mcp_total = mcp_payload("aggregate", {
        resource: "mcp_parity_widget", q: "alpha"
      }).fetch("count")

      assert_equal ui_total, mcp_total
    end
  end
end
