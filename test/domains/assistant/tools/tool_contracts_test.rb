# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class ToolContractsTest < ActiveSupport::TestCase
      test "all assistant tools return a valid contract shape for empty args" do
        user = create(:user, :with_applications, name: "Contract User")
        tool_execution = Assistant::ToolExecution.new

        tool_classes = Assistant::Tools.constants
          .map { |c| Assistant::Tools.const_get(c) }
          .select { |k| k.is_a?(Class) }
          .select { |k| k.name&.end_with?("Tool") }
          .reject { |k| k == Assistant::Tools::BaseTool }

        assert tool_classes.any?, "Expected at least one tool class"

        tool_classes.each do |klass|
          tool = klass.new(user: user)
          result = tool.call(args: {}, tool_execution: tool_execution)
          assert_assistant_tool_contract!(result)
        rescue StandardError => e
          flunk "Tool #{klass.name} raised: #{e.class}: #{e.message}"
        end
      end
    end
  end
end
