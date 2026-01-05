# frozen_string_literal: true

namespace :interview_applications do
  desc "Purge soft-deleted interview applications older than 3 months"
  task purge_deleted: :environment do
    PurgeDeletedInterviewApplicationsJob.perform_now
  end
end
