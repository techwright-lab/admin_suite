# frozen_string_literal: true

require "test_helper"

class GmailSyncServicePipelineThreadingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creates a pipeline run and enqueues ProcessSignalExtractionJob with run_id" do
    processor_new = Gmail::EmailProcessorService.instance_method(:initialize)
    processor_run = Gmail::EmailProcessorService.instance_method(:run)

    connected_account = create(:connected_account)
    app = create(:interview_application, user: connected_account.user)

    email = nil

    begin
      Gmail::EmailProcessorService.define_method(:initialize) do |synced_email, pipeline_run: nil|
        @synced_email = synced_email
        @pipeline_run = pipeline_run
      end
      Gmail::EmailProcessorService.define_method(:run) do
        @synced_email.email_type = "status_update"
        @synced_email.status = :processed
        { success: true, email_type: "status_update" }
      end

      parsed_emails = [ { "id" => "fake" } ]

      create_from_new = SyncedEmail.singleton_class.instance_method(:create_from_gmail_message)
      SyncedEmail.singleton_class.define_method(:create_from_gmail_message) do |user, account, _email_data|
        email = FactoryBot.create(
          :synced_email,
          user: user,
          connected_account: account,
          interview_application: app,
          status: :pending,
          extraction_status: "pending"
        )
        email
      end

      begin
        clear_enqueued_jobs
        assert_enqueued_jobs 0
        Gmail::SyncService.new(connected_account).send(:store_and_process_emails, parsed_emails)
        run = Signals::EmailPipelineRun.order(created_at: :desc).first
        assert run.present?
        assert_enqueued_with(job: ProcessSignalExtractionJob, args: [ email.id, run.id ])
      ensure
        SyncedEmail.singleton_class.define_method(:create_from_gmail_message, create_from_new)
      end
    ensure
      Gmail::EmailProcessorService.define_method(:initialize, processor_new)
      Gmail::EmailProcessorService.define_method(:run, processor_run)
    end
  end
end
