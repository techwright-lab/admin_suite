# frozen_string_literal: true

require "test_helper"

class Signals::ExtractionServiceTest < ActiveSupport::TestCase
  class MockProvider
    attr_reader :last_prompt

    def initialize(response)
      @response = response
      @last_prompt = nil
    end

    def available?
      true
    end

    def run(prompt, max_tokens:, temperature:, system_message:)
      @last_prompt = prompt
      @response
    end
  end

  test "filters and deduplicates action links from extraction results" do
    user = create(:user)
    connected_account = create(:connected_account, user:)
    email = create(:synced_email, user:, connected_account:, body_preview: "Interview details inside")

    response = {
      content: {
        company: { name: "Toptal" },
        action_links: [
          { url: "https://toptal.zoom.us/j/123", action_label: "Join Toptal Zoom interview", priority: 1 },
          { url: "https://www.google.com/url?q=https%3A%2F%2Ftoptal.zoom.us%2Fj%2F123", action_label: "Open Zoom interview link via Google Calendar redirect", priority: 2 },
          { url: "https://calendar.google.com/calendar/", action_label: "Open Google Calendar", priority: 4 },
          { url: "https://support.google.com/calendar/answer/37135#forwarding", action_label: "Learn about forwarding Google Calendar invitations", priority: 5 },
          { url: "https://meet.goodtime.io/x/abc123", action_label: "Reschedule interview", priority: 1 }
        ],
        suggested_actions: [ "start_application" ],
        confidence_score: 0.9
      }.to_json
    }

    provider = MockProvider.new(response)
    service = Signals::ExtractionService.new(email)
    service.define_singleton_method(:provider_chain) { %w[mock] }
    service.define_singleton_method(:get_provider_instance) { |_| provider }

    result = service.extract
    assert result[:success]

    email.reload
    links = email.signal_action_links

    assert_equal 2, links.size
    assert links.any? { |link| link["url"] == "https://toptal.zoom.us/j/123" }
    assert links.any? { |link| link["url"] == "https://meet.goodtime.io/x/abc123" }
  end

  test "prefers cleaned html when preview is short" do
    user = create(:user)
    connected_account = create(:connected_account, user:)
    html = <<~HTML
      <style>body { font-family: Roboto; }</style>
      <div style="display:none">hidden secret</div>
      <div>Hello Ravi, your interview is scheduled.</div>
    HTML
    email = create(:synced_email, user:, connected_account:, body_preview: "Short", body_html: html)

    response = { content: { confidence_score: 0.9 }.to_json }
    provider = MockProvider.new(response)
    service = Signals::ExtractionService.new(email)
    service.define_singleton_method(:provider_chain) { %w[mock] }
    service.define_singleton_method(:get_provider_instance) { |_| provider }

    result = service.extract
    assert result[:success]

    prompt = provider.last_prompt.to_s
    assert_includes prompt, "Hello Ravi, your interview is scheduled."
    refute_includes prompt, "font-family"
    refute_includes prompt, "hidden secret"
  end
end
