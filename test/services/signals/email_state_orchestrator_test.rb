# frozen_string_literal: true

require "test_helper"

class Signals::EmailStateOrchestratorTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @company = create(:company)
    @job_role = create(:job_role)
    @connected_account = create(:connected_account, user: @user)
    @application = create(:interview_application, user: @user, company: @company, job_role: @job_role)
  end

  test "skips when email is not matched" do
    email = create(:synced_email, :scheduling,
      user: @user,
      connected_account: @connected_account,
      interview_application: nil
    )

    result = Signals::EmailStateOrchestrator.new(email).call

    assert result[:skipped]
    assert_equal "Email not matched to application", result[:reason]
  end

  test "scheduling email updates pipeline stage from round stage" do
    email = create(:synced_email, :scheduling,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    fake_processor_class = Class.new do
      def initialize(email, application)
        @email = email
        @application = application
      end

      def process
        @application.interview_rounds.create!(
          stage: :screening,
          position: 1,
          result: :pending,
          source_email_id: @email.id
        )
        { success: true, action: :created }
      end
    end

    with_stubbed_new(Signals::InterviewRoundProcessor, ->(email) { fake_processor_class.new(email, @application) }) do
      result = Signals::EmailStateOrchestrator.new(email).call
      assert result[:success]
    end

    assert_equal "screening", @application.reload.pipeline_stage
  end

  test "round feedback failure rejects and closes application" do
    round = create(:interview_round,
      interview_application: @application,
      stage: :technical,
      result: :pending,
      position: 1
    )

    email = create(:synced_email, :round_feedback,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    fake_feedback_class = Class.new do
      def initialize(round)
        @round = round
      end

      def process
        @round.update!(result: :failed, completed_at: Time.current)
        { success: true, action: :updated, round: @round }
      end
    end

    with_stubbed_new(Signals::RoundFeedbackProcessor, ->(_email) { fake_feedback_class.new(round) }) do
      result = Signals::EmailStateOrchestrator.new(email).call
      assert result[:success]
    end

    @application.reload
    assert_equal "rejected", @application.status
    assert_equal "closed", @application.pipeline_stage
  end

  test "rejection email marks latest round failed" do
    round = create(:interview_round,
      interview_application: @application,
      stage: :screening,
      result: :pending,
      position: 1
    )

    email = create(:synced_email, :rejection,
      user: @user,
      connected_account: @connected_account,
      interview_application: @application
    )

    fake_status_class = Class.new do
      def process
        { success: true, action: :rejection }
      end
    end

    with_stubbed_new(Signals::ApplicationStatusProcessor, ->(_email) { fake_status_class.new }) do
      result = Signals::EmailStateOrchestrator.new(email).call
      assert result[:success]
    end

    assert_equal "failed", round.reload.result
  end

  private

  def with_stubbed_new(klass, replacement)
    original = klass.singleton_class.instance_method(:new)
    klass.singleton_class.send(:define_method, :new) do |*args, **kwargs, &block|
      replacement.call(*args, **kwargs, &block)
    end
    yield
  ensure
    klass.singleton_class.send(:define_method, :new, original)
  end
end
