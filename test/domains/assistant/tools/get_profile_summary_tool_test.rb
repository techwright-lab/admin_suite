# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class GetProfileSummaryToolTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool = GetProfileSummaryTool.new(user: @user)
        @tool_execution = Assistant::ToolExecution.new
      end

      test "returns success with user data without email" do
        result = @tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:user]
        assert_nil result[:data][:user][:email_address], "Email should not be exposed to LLM"
        assert result[:data][:user][:name].present? || result[:data][:user][:name].nil?
      end

      test "includes career context" do
        result = @tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:career]
        assert result[:data][:career].key?(:work_history)
        assert result[:data][:career].key?(:resume_summary) || result[:data][:career].key?(:strengths)
      end

      test "includes target lists with domains" do
        result = @tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        target_lists = result[:data][:target_lists]
        assert target_lists.key?(:companies_count)
        assert target_lists.key?(:job_roles_count)
        assert target_lists.key?(:domains_count)
      end

      test "respects top_skills_limit argument" do
        result = @tool.call(args: { "top_skills_limit" => 3 }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:top_skills].length <= 3
      end

      test "respects work_history_limit argument" do
        result = @tool.call(args: { "work_history_limit" => 2 }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:career][:work_history].length <= 2
      end
    end
  end
end
