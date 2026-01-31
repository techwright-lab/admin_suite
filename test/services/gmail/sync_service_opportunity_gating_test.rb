# frozen_string_literal: true

require "test_helper"

class GmailSyncServiceOpportunityGatingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "does not create opportunity in Gmail sync when decisioning opportunity creation flag enabled" do
    Setting.set(name: "signals_decision_opportunity_creation_enabled", value: true)

    connected_account = create(:connected_account)
    email = create(
      :synced_email,
      user: connected_account.user,
      connected_account: connected_account,
      status: :pending,
      extraction_status: "pending"
    )

    processor_new = Gmail::EmailProcessorService.instance_method(:initialize)
    processor_run = Gmail::EmailProcessorService.instance_method(:run)
    create_from_new = SyncedEmail.singleton_class.instance_method(:create_from_gmail_message)
    create_opp_new = Gmail::SyncService.instance_method(:create_opportunity_from_email)

    Gmail::EmailProcessorService.define_method(:initialize) do |synced_email, pipeline_run: nil|
      @synced_email = synced_email
      @pipeline_run = pipeline_run
    end
    Gmail::EmailProcessorService.define_method(:run) do
      { success: true, email_type: "recruiter_outreach" }
    end

    SyncedEmail.singleton_class.define_method(:create_from_gmail_message) { |_user, _account, _email_data| email }
    Gmail::SyncService.define_method(:create_opportunity_from_email) { |_synced_email| raise "should_not_be_called" }

    begin
      clear_enqueued_jobs
      Gmail::SyncService.new(connected_account).send(:store_and_process_emails, [ { "id" => "fake" } ])
      assert_equal 0, Opportunity.where(synced_email_id: email.id).count
    ensure
      Gmail::EmailProcessorService.define_method(:initialize, processor_new)
      Gmail::EmailProcessorService.define_method(:run, processor_run)
      SyncedEmail.singleton_class.define_method(:create_from_gmail_message, create_from_new)
      Gmail::SyncService.define_method(:create_opportunity_from_email, create_opp_new)
    end
  end
end
