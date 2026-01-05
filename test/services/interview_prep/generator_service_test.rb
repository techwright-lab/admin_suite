# frozen_string_literal: true

require "test_helper"

class InterviewPrep::GeneratorServiceTest < ActiveSupport::TestCase
  class DummyProvider
    attr_reader :seen_system_message

    def available?
      true
    end

    def run(_prompt, options = {})
      @seen_system_message = options[:system_message]
      {
        content: '{"strengths":[{"title":"Backend ownership","positioning":"Keep it crisp","evidence_types":["ownership"]}]}',
        model: "dummy-model",
        input_tokens: 10,
        output_tokens: 20,
        latency_ms: 5
      }
    end
  end

  test "uses active prompt system_prompt when calling provider" do
    user = create(:user)
    create(:billing_plan, :free) # satisfies Entitlements.free fallback lookups elsewhere

    # Ensure an active prompt with system_prompt exists
    create(
      :llm_prompt,
      type: "Ai::InterviewPrepStrengthPositioningPrompt",
      active: true,
      version: 1,
      system_prompt: "SYS_FROM_DB",
      prompt_template: Ai::InterviewPrepStrengthPositioningPrompt.default_prompt_template,
      variables: Ai::InterviewPrepStrengthPositioningPrompt.default_variables
    )

    application = create(:interview_application, user: user)
    dummy = DummyProvider.new

    service = InterviewPrep::GenerateStrengthPositioningService.new(user: user, interview_application: application)
    service.define_singleton_method(:provider_chain) { [ "dummy" ] }
    service.define_singleton_method(:provider_for) { |_name| dummy }

    artifact = service.call

    assert_equal "computed", artifact.status
    assert_equal "SYS_FROM_DB", dummy.seen_system_message
  end

  test "skips generation when artifact is computed and digest matches" do
    user = create(:user)
    application = create(:interview_application, user: user)

    digest = InterviewPrep::InputsBuilderService.new(user: user, interview_application: application).digest_for(:strength_positioning)
    create(
      :interview_prep_artifact,
      interview_application: application,
      user: user,
      kind: :strength_positioning,
      status: :computed,
      inputs_digest: digest,
      content: { "strengths" => [] },
      computed_at: Time.current
    )

    service = InterviewPrep::GenerateStrengthPositioningService.new(user: user, interview_application: application)
    service.define_singleton_method(:provider_chain) { raise "should not be called" }

    artifact = service.call
    assert_equal "computed", artifact.status
    assert_equal digest, artifact.inputs_digest
  end
end
