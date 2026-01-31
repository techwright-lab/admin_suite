# frozen_string_literal: true

require "test_helper"

class SignalsEmailPipelineRunTest < ActiveSupport::TestCase
  test "requires synced_email/user/connected_account and started_at" do
    run = Signals::EmailPipelineRun.new
    assert_not run.valid?

    email = create(:synced_email)
    run.synced_email = email
    run.user = email.user
    run.connected_account = email.connected_account
    run.started_at = Time.current
    run.trigger = "gmail_sync"
    run.mode = "mixed"

    assert run.valid?
  end
end
