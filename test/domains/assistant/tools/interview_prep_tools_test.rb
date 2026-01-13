# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class InterviewPrepToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
        company = Company.find_or_create_by!(name: "TestCompany")
        job_role = JobRole.find_or_create_by!(title: "Software Engineer")
        @application = @user.interview_applications.create!(
          company: company,
          job_role: job_role,
          status: "active",
          pipeline_stage: "screening"
        )
      end

      # GetInterviewPrepTool tests
      test "get_interview_prep returns success with application data" do
        tool = GetInterviewPrepTool.new(user: @user)
        result = tool.call(args: { "application_id" => @application.id }, tool_execution: @tool_execution)

        assert result[:success]
        assert result[:data][:application][:id] == @application.id
        assert result[:data].key?(:prep_artifacts)
        assert result[:data].key?(:has_all_artifacts)
      end

      test "get_interview_prep includes all artifact kinds" do
        tool = GetInterviewPrepTool.new(user: @user)
        result = tool.call(args: { "application_id" => @application.id }, tool_execution: @tool_execution)

        assert result[:success]
        artifacts = result[:data][:prep_artifacts]

        InterviewPrepArtifact::KINDS.each do |kind|
          assert artifacts.key?(kind), "Should include #{kind} artifact"
        end
      end

      test "get_interview_prep requires application_id" do
        tool = GetInterviewPrepTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "application_id"
      end

      test "get_interview_prep fails for nonexistent application" do
        tool = GetInterviewPrepTool.new(user: @user)
        result = tool.call(args: { "application_id" => 999999 }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end

      test "get_interview_prep fails for other users application" do
        other_user = create(:user, name: "Other User")
        company = Company.find_or_create_by!(name: "OtherCompany")
        job_role = JobRole.find_or_create_by!(title: "Other Role")
        other_app = other_user.interview_applications.create!(
          company: company,
          job_role: job_role,
          status: "active"
        )

        tool = GetInterviewPrepTool.new(user: @user)
        result = tool.call(args: { "application_id" => other_app.id }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end

      # GenerateInterviewPrepTool tests (basic structure tests - actual generation requires LLM)
      test "generate_interview_prep requires application_id" do
        tool = GenerateInterviewPrepTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "application_id"
      end

      test "generate_interview_prep fails for nonexistent application" do
        tool = GenerateInterviewPrepTool.new(user: @user)
        result = tool.call(args: { "application_id" => 999999 }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "not found"
      end

      test "generate_interview_prep validates kinds parameter" do
        tool = GenerateInterviewPrepTool.new(user: @user)

        # With invalid kinds, should default to all valid kinds
        result = tool.call(
          args: { "application_id" => @application.id, "kinds" => [ "invalid_kind" ] },
          tool_execution: @tool_execution
        )

        # This would fail but with "at least one prep type" error
        assert_not result[:success]
        assert_includes result[:error], "prep type"
      end
    end
  end
end
