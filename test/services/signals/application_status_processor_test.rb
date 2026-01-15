# frozen_string_literal: true

require "test_helper"

class Signals::ApplicationStatusProcessorTest < ActiveSupport::TestCase
  # Mock LLM provider for testing
  class MockProvider
    attr_accessor :response, :should_fail

    def initialize
      @response = default_rejection_response
      @should_fail = false
    end

    def available?
      true
    end

    def run(_prompt, **_options)
      raise StandardError, "Provider failed" if @should_fail

      @response
    end

    def default_rejection_response
      {
        content: JSON.generate({
          status_change: {
            type: "rejection",
            is_final: true
          },
          sentiment: "neutral",
          rejection_details: {
            reason: "Position filled with another candidate",
            stage_rejected_at: "technical",
            is_generic: false,
            door_open: true
          },
          feedback: {
            has_feedback: true,
            feedback_text: "Thank you for your interest. We were impressed with your skills."
          },
          confidence_score: 0.95
        }),
        model: "mock-model",
        input_tokens: 100,
        output_tokens: 80,
        latency_ms: 150
      }
    end

    def default_offer_response
      {
        content: JSON.generate({
          status_change: {
            type: "offer",
            is_final: false
          },
          sentiment: "positive",
          offer_details: {
            role_title: "Senior Software Engineer",
            department: "Platform Engineering",
            start_date: "2026-02-01",
            response_deadline: "2026-01-25",
            next_steps: "Review the attached offer letter"
          },
          feedback: {
            has_feedback: true,
            feedback_text: "We are thrilled to extend this offer based on your excellent performance."
          },
          confidence_score: 0.98
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
    @application = create(:interview_application,
      user: @user,
      company: @company,
      job_role: @job_role,
      status: :active,
      pipeline_stage: :interviewing
    )
    @mock_provider = MockProvider.new
  end

  # Rejection tests
  test "updates application status to rejected" do
    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)
    result = processor.process

    assert result[:success]
    assert_equal :rejection, result[:action]

    @application.reload
    assert_equal "rejected", @application.status
    assert_equal "closed", @application.pipeline_stage
  end

  test "creates rejection feedback" do
    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)

    assert_difference "CompanyFeedback.count", 1 do
      result = processor.process
      assert result[:success]
    end

    feedback = @application.reload.company_feedback
    assert_not_nil feedback
    assert_equal "rejection", feedback.feedback_type
    assert_includes feedback.rejection_reason, "Position filled"
    assert_equal rejection_email.id, feedback.source_email_id
  end

  # Offer tests
  test "moves application to offer stage" do
    @mock_provider.response = @mock_provider.default_offer_response

    offer_email = create(:synced_email, :offer,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(offer_email)
    result = processor.process

    assert result[:success]
    assert_equal :offer, result[:action]

    @application.reload
    assert_equal "active", @application.status
    assert_equal "offer", @application.pipeline_stage
  end

  test "creates offer feedback with next steps" do
    @mock_provider.response = @mock_provider.default_offer_response

    offer_email = create(:synced_email, :offer,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(offer_email)

    assert_difference "CompanyFeedback.count", 1 do
      result = processor.process
      assert result[:success]
    end

    feedback = @application.reload.company_feedback
    assert_not_nil feedback
    assert_equal "offer", feedback.feedback_type
    assert_includes feedback.feedback_text, "Offer received"
    assert_includes feedback.next_steps, "Respond by: 2026-01-25"
    assert_includes feedback.next_steps, "Start date: 2026-02-01"
    assert_equal offer_email.id, feedback.source_email_id
  end

  # Skip conditions
  test "skips when email not matched to application" do
    unmatched_email = create(:synced_email, :rejection,
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

  test "skips when email type is not rejection or offer" do
    other_email = create(:synced_email, :scheduling,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(other_email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "Email type not processable", result[:reason]
  end

  test "skips when no email content" do
    empty_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application,
      body_preview: nil,
      body_html: nil,
      snippet: nil
    )

    processor = build_processor(empty_email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
  end

  # Confidence tests
  test "rejects low confidence extractions" do
    @mock_provider.response[:content] = JSON.generate({
      status_change: { type: "rejection" },
      confidence_score: 0.4
    })

    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)
    result = processor.process

    assert_not result[:success]
    assert_equal "active", @application.reload.status
  end

  # Status change detection
  test "skips when no status change detected" do
    @mock_provider.response[:content] = JSON.generate({
      status_change: {
        type: "unknown"
      },
      confidence_score: 0.9
    })

    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "No status change detected", result[:reason]
  end

  # Duplicate feedback prevention
  test "does not create duplicate feedback" do
    create(:company_feedback,
      interview_application: @application,
      feedback_type: :rejection
    )

    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)

    assert_no_difference "CompanyFeedback.count" do
      result = processor.process
      # Still succeeds for status update
      assert result[:success]
    end
  end

  # API logging tests
  test "logs extraction result to LlmApiLog" do
    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)

    assert_difference "Ai::LlmApiLog.count", 1 do
      result = processor.process
      assert result[:success]
    end

    log = Ai::LlmApiLog.last
    assert_equal "application_status_extraction", log.operation_type
    assert_equal "mock-provider", log.provider
    assert_equal "success", log.status
  end

  # State machine tests
  test "does not reject already rejected application" do
    @application.update!(status: :rejected, pipeline_stage: :closed)

    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)

    # Should not raise error, just skip the status update
    result = processor.process
    assert result[:success]
    assert_equal "rejected", @application.reload.status
  end

  # Door open indicator
  test "sets next steps when door is open" do
    @mock_provider.response[:content] = JSON.generate({
      status_change: { type: "rejection", is_final: true },
      rejection_details: {
        reason: "Position filled",
        door_open: true
      },
      confidence_score: 0.9
    })

    rejection_email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(rejection_email)
    processor.process

    feedback = @application.reload.company_feedback
    assert_includes feedback.next_steps, "Keep in touch for future opportunities"
  end

  private

  def build_processor(email)
    mock = @mock_provider
    processor = Signals::ApplicationStatusProcessor.new(email)
    processor.define_singleton_method(:provider_chain) { %w[mock-provider] }
    processor.define_singleton_method(:get_provider_instance) { |_| mock }
    processor
  end
end
