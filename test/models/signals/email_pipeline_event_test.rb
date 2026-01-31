# frozen_string_literal: true

require "test_helper"

class SignalsEmailPipelineEventTest < ActiveSupport::TestCase
  test "requires run, synced_email, event_type, and step_order" do
    event = Signals::EmailPipelineEvent.new
    assert_not event.valid?

    email = create(:synced_email)
    run = Signals::EmailPipelineRun.create!(
      synced_email: email,
      user: email.user,
      connected_account: email.connected_account,
      trigger: "manual",
      mode: "mixed",
      started_at: Time.current
    )

    event.run = run
    event.synced_email = email
    event.event_type = :synced_email_upsert
    event.step_order = 1

    assert event.valid?
  end
end
