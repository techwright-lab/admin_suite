# frozen_string_literal: true

require "test_helper"

class Signals::RoundFeedbackProcessorTest < ActiveSupport::TestCase
  # Mock LLM provider for testing
  class MockProvider
    attr_accessor :response, :should_fail

    def initialize
      @response = default_response
      @should_fail = false
    end

    def available?
      true
    end

    def run(_prompt, **_options)
      raise StandardError, "Provider failed" if @should_fail

      @response
    end

    def default_response
      {
        content: JSON.generate({
          result: "passed",
          sentiment: "positive",
          round_context: {
            stage_mentioned: "phone screen",
            interviewer_mentioned: "Jane Smith"
          },
          feedback: {
            has_detailed_feedback: true,
            summary: "Candidate passed the phone screen with strong performance",
            strengths: [ "Strong communication", "Good problem-solving" ],
            improvements: [ "Could improve on system design" ]
          },
          next_steps: {
            has_next_round: true,
            next_round_type: "technical interview",
            next_round_hint: "Technical round with senior engineers"
          },
          confidence_score: 0.95
        }),
        model: "mock-model",
        input_tokens: 100,
        output_tokens: 80,
        latency_ms: 150
      }
    end
  end

  def setup
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @connected_account = create(:connected_account, user: @user)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
    @mock_provider = MockProvider.new

    # Create a pending round
    @pending_round = create(:interview_round, :screening,
      interview_application: @application,
      interviewer_name: "Jane Smith",
      result: :pending
    )

    # Create round feedback email
    @email = create(:synced_email, :round_feedback,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )
  end

  # Basic functionality tests
  test "updates round result from feedback email" do
    processor = build_processor(@email)

    result = processor.process

    assert result[:success]
    assert_equal :updated, result[:action]

    @pending_round.reload
    assert_equal "passed", @pending_round.result
    assert_not_nil @pending_round.completed_at
    assert_equal @email.id, @pending_round.source_email_id
  end

  test "creates interview feedback record" do
    processor = build_processor(@email)

    assert_difference "InterviewFeedback.count", 1 do
      result = processor.process
      assert result[:success]
    end

    feedback = @pending_round.reload.interview_feedback
    assert_not_nil feedback
    assert_includes feedback.went_well, "Strong communication"
    assert_includes feedback.to_improve, "Could improve on system design"
    assert_equal "Candidate passed the phone screen with strong performance", feedback.ai_summary
    assert_includes feedback.recommended_action, "technical"
  end

  test "skips when email not matched to application" do
    unmatched_email = create(:synced_email, :round_feedback,
      user: @user,
      connected_account: @connected_account,
      interview_application: nil
    )

    processor = build_processor(unmatched_email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "Email not matched to application", result[:reason]
  end

  test "skips when email type is not round_feedback" do
    other_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application,
      email_type: "interview_invite"
    )

    processor = build_processor(other_email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "Email type not processable", result[:reason]
  end

  # Result mapping tests
  test "maps passed result correctly" do
    @mock_provider.response[:content] = JSON.generate({
      result: "passed",
      confidence_score: 0.9
    })

    processor = build_processor(@email)
    processor.process

    assert_equal "passed", @pending_round.reload.result
  end

  test "maps failed result correctly" do
    @mock_provider.response[:content] = JSON.generate({
      result: "failed",
      confidence_score: 0.9
    })

    processor = build_processor(@email)
    processor.process

    assert_equal "failed", @pending_round.reload.result
  end

  test "maps waitlisted result correctly" do
    @mock_provider.response[:content] = JSON.generate({
      result: "waitlisted",
      confidence_score: 0.9
    })

    processor = build_processor(@email)
    processor.process

    assert_equal "waitlisted", @pending_round.reload.result
  end

  # Round matching tests
  test "matches round by interviewer name" do
    @mock_provider.response[:content] = JSON.generate({
      result: "passed",
      round_context: {
        interviewer_mentioned: "Jane Smith"
      },
      confidence_score: 0.9
    })

    # Create another round with different interviewer
    other_round = create(:interview_round, :technical,
      interview_application: @application,
      interviewer_name: "Bob Engineer",
      result: :pending
    )

    processor = build_processor(@email)
    result = processor.process

    assert result[:success]
    # Should update the round with Jane Smith
    assert_equal "passed", @pending_round.reload.result
    assert_equal "pending", other_round.reload.result
  end

  test "matches round by stage hint" do
    @mock_provider.response[:content] = JSON.generate({
      result: "passed",
      round_context: {
        stage_mentioned: "technical interview"
      },
      confidence_score: 0.9
    })

    # Create technical round
    technical_round = create(:interview_round, :technical,
      interview_application: @application,
      result: :pending
    )

    processor = build_processor(@email)
    result = processor.process

    assert result[:success]
    # Should update the technical round
    assert_equal "passed", technical_round.reload.result
  end

  test "falls back to most recent pending round" do
    @mock_provider.response[:content] = JSON.generate({
      result: "passed",
      round_context: {},
      confidence_score: 0.9
    })

    processor = build_processor(@email)
    result = processor.process

    assert result[:success]
    # Should update the most recent pending round
    assert_equal "passed", @pending_round.reload.result
  end

  # Creates round when no match found
  test "creates new round when no matching round found" do
    # Delete all existing rounds
    @application.interview_rounds.destroy_all

    processor = build_processor(@email)

    assert_difference "InterviewRound.count", 1 do
      result = processor.process
      assert result[:success]
      assert_equal :created, result[:action]
    end

    new_round = @application.interview_rounds.last
    assert_equal "passed", new_round.result
    assert_not_nil new_round.completed_at
    assert_equal @email.id, new_round.source_email_id
  end

  # Confidence tests
  test "rejects low confidence extractions" do
    @mock_provider.response[:content] = JSON.generate({
      result: "passed",
      confidence_score: 0.3
    })

    processor = build_processor(@email)
    result = processor.process

    assert_not result[:success]
    assert_equal "pending", @pending_round.reload.result
  end

  # API logging tests
  test "logs extraction result to LlmApiLog" do
    processor = build_processor(@email)

    assert_difference "Ai::LlmApiLog.count", 1 do
      result = processor.process
      assert result[:success]
    end

    log = Ai::LlmApiLog.last
    assert_equal "round_feedback_extraction", log.operation_type
    assert_equal "mock-provider", log.provider
    assert_equal "success", log.status
  end

  # Duplicate feedback prevention
  test "does not create duplicate feedback" do
    # Create existing feedback
    create(:interview_feedback, interview_round: @pending_round)

    processor = build_processor(@email)

    assert_no_difference "InterviewFeedback.count" do
      result = processor.process
      assert result[:success]
    end
  end

  private

  def build_processor(email)
    mock = @mock_provider
    processor = Signals::RoundFeedbackProcessor.new(email)
    processor.define_singleton_method(:provider_chain) { %w[mock-provider] }
    processor.define_singleton_method(:get_provider_instance) { |_| mock }
    processor
  end
end
