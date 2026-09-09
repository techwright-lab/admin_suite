# frozen_string_literal: true

require "test_helper"

class McpSerializerTest < ActiveSupport::TestCase
  Column = Data.define(:name)
  Index = Data.define(:columns_list)
  Config = Data.define(:index_config)

  test "emits only the resource's declared columns" do
    record = Struct.new(:id, :name, :secret_token).new(1, "Widget", "sh-hh")
    config = Config.new(Index.new([Column.new(:id), Column.new(:name)]))

    row = AdminSuite::Mcp::Serializer.index_row(record, config)

    assert_equal %w[id name], row.keys.map(&:to_s).sort
    refute_includes row.keys.map(&:to_s), "secret_token"
  end

  test "a raising accessor degrades that cell, not the row" do
    record = Object.new
    def record.id = 1
    def record.name = raise("boom")
    config = Config.new(Index.new([Column.new(:id), Column.new(:name)]))

    row = AdminSuite::Mcp::Serializer.index_row(record, config)

    assert_equal 1, row[:id]
    assert_nil row[:name]
  end

  test "association panels return bounded rows containing only declared columns" do
    show = Admin::Base::Resource::ShowConfig.new
    show.panel :children, association: :children, columns: [:name], limit: 500
    config = Struct.new(:show_config).new(show)
    child = Struct.new(:name, :secret_token).new("Visible", "private")
    record = Struct.new(:children).new(Array.new(150, child))

    payload = AdminSuite::Mcp::Serializer.associations_payload(record, config, max_rows: 100)
    assert_equal 100, payload.fetch(:children).fetch(:rows).size
    assert_equal({ name: "Visible" }, payload.fetch(:children).fetch(:rows).first)
    assert_equal 100, payload.fetch(:children).fetch(:applied_limit)
    refute_includes JSON.generate(payload), "private"
  end

  test "association panels without declared columns do not serialize model attributes" do
    show = Admin::Base::Resource::ShowConfig.new
    show.panel :children, association: :children
    config = Struct.new(:show_config).new(show)
    record = Object.new
    def record.children = raise("must not load an undeclared field set")

    assert_empty AdminSuite::Mcp::Serializer.associations_payload(record, config, max_rows: 100)
  end
end
