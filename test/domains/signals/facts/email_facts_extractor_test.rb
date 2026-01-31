# frozen_string_literal: true

require "test_helper"

class SignalsEmailFactsExtractorTest < ActiveSupport::TestCase
  test "persists email_facts_v1 when provider returns schema-valid JSON" do
    email = create(:synced_email, :with_extraction, status: :processed)
    builder = Signals::Decisioning::DecisionInputBuilder.new(email)
    base = builder.build_base

    fake_facts = JSON.parse(File.read(Rails.root.join("app/domains/signals/contracts/examples/decision_input/offer.json"))).fetch("facts")

    fake_runner = Class.new do
      def initialize(*); end
      def run
        response = { content: JSON.generate(@fake_facts || {}) }
        parsed, log_data, accept = yield(response)
        { success: true, provider: "openai", model: "unknown", parsed: parsed, llm_api_log_id: 123, latency_ms: 1 }
      end
      def set_facts(facts) = (@fake_facts = facts)
    end

    # Stub ProviderRunnerService.new to return our fake runner instance.
    runner_instance = fake_runner.new
    runner_instance.set_facts(fake_facts)
    original_new = Ai::ProviderRunnerService.singleton_class.instance_method(:new)
    Ai::ProviderRunnerService.singleton_class.define_method(:new) { |*args, **kwargs| runner_instance }

    begin
      res = Signals::Facts::EmailFactsExtractor.new(email, decision_input_base: base).call
      assert res[:success]
      email.reload
      assert email.extracted_data["email_facts_v1"].is_a?(Hash)
      assert_equal "status_update", email.extracted_data["email_facts_v1"].dig("classification", "kind")
    ensure
      Ai::ProviderRunnerService.singleton_class.define_method(:new, original_new)
    end
  end
end
