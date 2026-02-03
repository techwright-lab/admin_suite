# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class ListInterviewApplicationsToolTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Tool User")
        @tool_execution = Assistant::ToolExecution.new

        create(:interview_application, :active, user: @user, pipeline_stage: :applied)
        create(:interview_application, :active, user: @user, pipeline_stage: :screening)
        create(:interview_application, :rejected, user: @user, pipeline_stage: :closed)
      end

      test "returns all applications when status and pipeline_stage are 'all'" do
        tool = ListInterviewApplicationsTool.new(user: @user)
        result = tool.call(
          args: { "status" => "all", "pipeline_stage" => "all", "limit" => 50 },
          tool_execution: @tool_execution
        )

        assert result[:success]
        assert_equal 3, result.dig(:data, :count)
        assert_equal 3, result.dig(:data, :applications).size
      end

      test "filters by status when status is provided" do
        tool = ListInterviewApplicationsTool.new(user: @user)
        result = tool.call(
          args: { "status" => "active", "limit" => 50 },
          tool_execution: @tool_execution
        )

        assert result[:success]
        assert_equal 2, result.dig(:data, :count)
        statuses = result.dig(:data, :applications).map { |a| a[:status] || a["status"] }.uniq
        assert_equal [ "active" ], statuses
      end

      test "filters by pipeline_stage when pipeline_stage is provided" do
        tool = ListInterviewApplicationsTool.new(user: @user)
        result = tool.call(
          args: { "pipeline_stage" => "screening", "limit" => 50 },
          tool_execution: @tool_execution
        )

        assert result[:success]
        assert_equal 1, result.dig(:data, :count)
        stages = result.dig(:data, :applications).map { |a| a[:pipeline_stage] || a["pipeline_stage"] }.uniq
        assert_equal [ "screening" ], stages
      end
    end
  end
end
