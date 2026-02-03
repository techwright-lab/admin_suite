# frozen_string_literal: true

require "active_support/json"

# Shared assertions for Assistant tool result payloads.
#
# These enforce a consistent, safe-to-serialize contract:
# - result is a Hash
# - result includes boolean :success
# - success results include :data
# - failure results include :error
# - result does not include ActiveRecord objects/relations anywhere inside
module AssistantToolContractAssertions
  # @param result [Hash]
  # @return [void]
  def assert_assistant_tool_contract!(result)
    assert result.is_a?(Hash), "Expected tool result to be a Hash, got: #{result.class}"
    assert_includes result.keys, :success
    assert_includes [ true, false ], result[:success]

    if result[:success]
      assert_includes result.keys, :data
    else
      assert_includes result.keys, :error
      assert result[:error].to_s.present?, "Expected :error to be present on failure"
    end

    assert_no_active_record_objects!(result)
    assert_json_serializable!(result)
  end

  private

  def assert_json_serializable!(value)
    ActiveSupport::JSON.encode(value)
  rescue StandardError => e
    flunk "Expected tool result to be JSON serializable. Error=#{e.class}: #{e.message}"
  end

  def assert_no_active_record_objects!(value, path: "$")
    case value
    when ActiveRecord::Base
      flunk "Tool result contains ActiveRecord model at #{path}: #{value.class}"
    when ActiveRecord::Relation
      flunk "Tool result contains ActiveRecord relation at #{path}: #{value.class}"
    when Hash
      value.each do |k, v|
        assert_no_active_record_objects!(v, path: "#{path}.#{k}")
      end
    when Array
      value.each_with_index do |v, idx|
        assert_no_active_record_objects!(v, path: "#{path}[#{idx}]")
      end
    end
  end
end
