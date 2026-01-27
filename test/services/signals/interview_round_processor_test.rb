# frozen_string_literal: true

require "test_helper"

class Signals::InterviewRoundProcessorTest < ActiveSupport::TestCase
  # Mock LLM provider for testing
  class MockProvider
    attr_accessor :response, :should_fail, :should_rate_limit

    def initialize
      @response = default_response
      @should_fail = false
      @should_rate_limit = false
    end

    def available?
      true
    end

    def run(_prompt, **_options)
      return { error: "Provider error", rate_limit: true } if @should_rate_limit
      raise StandardError, "Provider failed" if @should_fail

      @response
    end

    def default_response
      {
        content: JSON.generate({
          interview: {
            scheduled_at: 2.days.from_now.iso8601,
            duration_minutes: 45,
            stage: "screening",
            stage_name: "Phone Screen"
          },
          interviewer: {
            name: "Sarah Chen",
            role: "Senior Recruiter",
            email: "sarah@example.com"
          },
          logistics: {
            video_link: "https://zoom.us/j/123456789",
            meeting_id: "123456789"
          },
          confirmation_source: "goodtime",
          confidence_score: 0.95
        }),
        model: "mock-model",
        input_tokens: 100,
        output_tokens: 50,
        latency_ms: 100
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

    # Create scheduling email
    @email = create(:synced_email, :scheduling,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )
  end

  # Basic functionality tests
  test "creates interview round from scheduling email" do
    processor = build_processor(@email)

    result = processor.process

    assert result[:success]
    assert_equal :created, result[:action]
    assert_not_nil result[:round]

    round = result[:round]
    assert round.persisted?
    assert_equal @application.id, round.interview_application_id
    assert_equal "screening", round.stage
    assert_equal "Sarah Chen", round.interviewer_name
    assert_equal "Senior Recruiter", round.interviewer_role
    assert_equal 45, round.duration_minutes
    assert_equal "https://zoom.us/j/123456789", round.video_link
    assert_equal "goodtime", round.confirmation_source
    assert_equal @email.id, round.source_email_id
  end

  test "skips when email not matched to application" do
    unmatched_email = create(:synced_email, :scheduling,
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

  test "skips when email type is not processable" do
    other_email = create(:synced_email,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application,
      email_type: "other"
    )

    processor = build_processor(other_email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "Email type not processable", result[:reason]
  end

  test "skips when email already processed" do
    # Create a round already linked to this email
    create(:interview_round,
      interview_application: @application,
      source_email_id: @email.id
    )

    processor = build_processor(@email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "Already processed", result[:reason]
    assert_not_nil result[:round]
  end

  test "skips when no email content available" do
    empty_email = create(:synced_email, :scheduling,
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
    assert_equal "No email content", result[:reason]
  end

  test "skips when only scheduling link is present without a confirmed time" do
    @mock_provider.response[:content] = JSON.generate({
      interview: {
        scheduled_at: nil,
        duration_minutes: 30,
        stage: "screening"
      },
      logistics: {
        video_link: nil
      },
      confirmation_source: "calendly",
      confidence_score: 0.9
    })

    processor = build_processor(@email)
    result = processor.process

    assert_not result[:success]
    assert result[:skipped]
    assert_equal "Insufficient scheduling signal", result[:reason]
  end

  # Provider chain tests
  test "tries next provider when first fails" do
    fail_provider = MockProvider.new
    fail_provider.should_fail = true

    success_provider = MockProvider.new

    processor = Signals::InterviewRoundProcessor.new(@email)
    processor.define_singleton_method(:provider_chain) { %w[failing success] }
    processor.define_singleton_method(:get_provider_instance) do |name|
      name == "failing" ? fail_provider : success_provider
    end

    result = processor.process

    assert result[:success]
    assert_equal :created, result[:action]
  end

  test "skips rate-limited providers" do
    rate_limited_provider = MockProvider.new
    rate_limited_provider.should_rate_limit = true

    success_provider = MockProvider.new

    processor = Signals::InterviewRoundProcessor.new(@email)
    processor.define_singleton_method(:provider_chain) { %w[limited success] }
    processor.define_singleton_method(:get_provider_instance) do |name|
      name == "limited" ? rate_limited_provider : success_provider
    end

    result = processor.process

    assert result[:success]
  end

  test "returns error when all providers fail" do
    fail_provider = MockProvider.new
    fail_provider.should_fail = true

    processor = Signals::InterviewRoundProcessor.new(@email)
    processor.define_singleton_method(:provider_chain) { %w[fail1 fail2] }
    processor.define_singleton_method(:get_provider_instance) { |_| fail_provider }

    result = processor.process

    assert_not result[:success]
    assert_equal "Failed to extract interview data from email", result[:error]
  end

  # Confidence score tests
  test "rejects low confidence extractions" do
    low_confidence_provider = MockProvider.new
    low_confidence_provider.response = {
      content: JSON.generate({ confidence_score: 0.3 }),
      model: "mock-model",
      input_tokens: 100,
      output_tokens: 50
    }

    processor = Signals::InterviewRoundProcessor.new(@email)
    processor.define_singleton_method(:provider_chain) { %w[low_conf] }
    processor.define_singleton_method(:get_provider_instance) { |_| low_confidence_provider }

    result = processor.process

    assert_not result[:success]
  end

  # Interview type tests
  test "processes interview_invite emails" do
    invite_email = create(:synced_email, :interview_invite,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    processor = build_processor(invite_email)
    result = processor.process

    assert result[:success]
    assert_equal :created, result[:action]
  end

  test "processes interview_reminder emails" do
    reminder_email = create(:synced_email, :interview_reminder,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application,
      body_preview: "Reminder about your interview tomorrow at 2pm"
    )

    processor = build_processor(reminder_email)
    result = processor.process

    assert result[:success]
  end

  # Update existing round tests
  test "updates existing round when scheduled time matches" do
    scheduled_at = 2.days.from_now

    # Create existing round at same time
    existing_round = create(:interview_round,
      interview_application: @application,
      scheduled_at: scheduled_at,
      video_link: nil
    )

    # Mock response with matching time
    @mock_provider.response[:content] = JSON.generate({
      interview: {
        scheduled_at: scheduled_at.iso8601,
        duration_minutes: 45
      },
      logistics: {
        video_link: "https://zoom.us/j/999"
      },
      confidence_score: 0.95
    })

    processor = build_processor(@email)
    result = processor.process

    # Should not create a new round
    assert_equal existing_round.id, @application.interview_rounds.last.id
    assert_equal "https://zoom.us/j/999", existing_round.reload.video_link
  end

  test "updates most recent unscheduled round when confirmed time arrives" do
    unscheduled_round = create(:interview_round,
      interview_application: @application,
      stage: :screening,
      scheduled_at: nil,
      video_link: nil,
      created_at: 2.days.ago
    )

    scheduled_at = 3.days.from_now
    @mock_provider.response[:content] = JSON.generate({
      interview: {
        scheduled_at: scheduled_at.iso8601,
        duration_minutes: 30,
        stage: "screening"
      },
      logistics: {
        video_link: "https://zoom.us/j/777"
      },
      confidence_score: 0.9
    })

    processor = build_processor(@email)
    result = processor.process

    assert result[:success]
    assert_equal unscheduled_round.id, result[:round].id
    assert_equal scheduled_at.to_i, result[:round].scheduled_at.to_i
    assert_equal "https://zoom.us/j/777", result[:round].video_link
  end

  # API logging tests
  test "logs extraction result to LlmApiLog" do
    processor = build_processor(@email)

    assert_difference "Ai::LlmApiLog.count", 1 do
      result = processor.process
      assert result[:success]
    end

    log = Ai::LlmApiLog.last
    assert_equal "interview_round_extraction", log.operation_type
    assert_equal "mock-provider", log.provider
    assert_equal "success", log.status
    assert_not_nil log.confidence_score
  end

  private

  def build_processor(email)
    mock = @mock_provider
    processor = Signals::InterviewRoundProcessor.new(email)
    processor.define_singleton_method(:provider_chain) { %w[mock-provider] }
    processor.define_singleton_method(:get_provider_instance) { |_| mock }
    processor
  end
end
