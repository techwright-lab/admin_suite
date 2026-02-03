# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class InterviewApplicationToolsTest < ActiveSupport::TestCase
      setup do
        @user = create(:user, name: "Test User")
        @tool_execution = Assistant::ToolExecution.new
        @application = create(:interview_application, user: @user, status: :active, pipeline_stage: :screening)
      end

      test "get_interview_application requires application_uuid" do
        tool = GetInterviewApplicationTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "application_uuid"
      end

      test "get_interview_application returns application and rounds" do
        create(:interview_round, :screening, interview_application: @application)
        create(:interview_round, :technical, interview_application: @application)

        tool = GetInterviewApplicationTool.new(user: @user)
        result = tool.call(args: { "application_uuid" => @application.uuid }, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal @application.uuid, result.dig(:data, :application, :uuid)
        assert result.dig(:data, :interview_rounds).is_a?(Array)
        assert_equal 2, result.dig(:data, :interview_rounds).size
      end

      test "add_note_to_application appends notes by default" do
        @application.update!(notes: "Existing note")
        tool = AddNoteToApplicationTool.new(user: @user)

        result = tool.call(
          args: { "application_uuid" => @application.uuid, "note" => "New note" },
          tool_execution: @tool_execution
        )

        assert result[:success], result[:error]
        @application.reload
        assert_includes @application.notes, "Existing note"
        assert_includes @application.notes, "New note"
      end

      test "add_note_to_application can replace notes" do
        @application.update!(notes: "Old")
        tool = AddNoteToApplicationTool.new(user: @user)

        result = tool.call(
          args: { "application_uuid" => @application.uuid, "note" => "Replaced", "mode" => "replace" },
          tool_execution: @tool_execution
        )

        assert result[:success], result[:error]
        @application.reload
        assert_equal "Replaced", @application.notes
      end

      test "create_interview_round creates a round on an application" do
        tool = CreateInterviewRoundTool.new(user: @user)
        scheduled = 2.days.from_now.iso8601

        result = tool.call(
          args: { "application_uuid" => @application.uuid, "stage" => "technical", "scheduled_at" => scheduled },
          tool_execution: @tool_execution
        )

        assert result[:success], result[:error]
        assert result.dig(:data, :interview_round, :id).present?
        assert_equal @application.uuid, result.dig(:data, :interview_application, :uuid)
      end

      test "upsert_interview_feedback creates feedback and get_interview_feedback returns it" do
        round = create(:interview_round, :technical, interview_application: @application)

        upsert = UpsertInterviewFeedbackTool.new(user: @user)
        upsert_result = upsert.call(
          args: { "interview_round_id" => round.id, "went_well" => "Did great", "tags" => [ "Tag1" ] },
          tool_execution: @tool_execution
        )

        assert upsert_result[:success], upsert_result[:error]

        getter = GetInterviewFeedbackTool.new(user: @user)
        get_result = getter.call(args: { "interview_round_id" => round.id }, tool_execution: @tool_execution)

        assert get_result[:success], get_result[:error]
        assert_equal round.id, get_result.dig(:data, :interview_round_id)
        assert_equal "Did great", get_result.dig(:data, :interview_feedback, :went_well)
      end

      test "get_next_interview returns nil when no upcoming rounds" do
        tool = GetNextInterviewTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success]
        assert_nil result.dig(:data, :next_interview)
      end

      test "get_next_interview returns the next upcoming round" do
        future = create(:interview_round, :upcoming, interview_application: @application, scheduled_at: 3.days.from_now)
        create(:interview_round, :upcoming, interview_application: @application, scheduled_at: 10.days.from_now)

        tool = GetNextInterviewTool.new(user: @user)
        result = tool.call(args: {}, tool_execution: @tool_execution)

        assert result[:success], result[:error]
        assert_equal future.id, result.dig(:data, :next_interview, :interview_round, :id)
      end

      test "tools do not allow reading other user's interview feedback" do
        other_user = create(:user, name: "Other User")
        other_app = create(:interview_application, user: other_user)
        other_round = create(:interview_round, interview_application: other_app)

        getter = GetInterviewFeedbackTool.new(user: @user)
        result = getter.call(args: { "interview_round_id" => other_round.id }, tool_execution: @tool_execution)

        assert_not result[:success]
        assert_includes result[:error], "Not authorized"
      end
    end
  end
end
