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
end
