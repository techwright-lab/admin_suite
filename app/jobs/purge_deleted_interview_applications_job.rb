# frozen_string_literal: true

# Purges soft-deleted interview applications that have been in Deleted for longer than the retention period.
#
# Intended to be run on a schedule (e.g. daily) via Solid Queue / cron / deploy scheduler.
class PurgeDeletedInterviewApplicationsJob < ApplicationJob
  queue_as :default

  # @param retention_period [ActiveSupport::Duration] Time to retain deleted records before hard deletion.
  def perform(retention_period: 3.months)
    cutoff = Time.current - retention_period

    InterviewApplication.deleted.where("deleted_at < ?", cutoff).find_each do |application|
      application.destroy!
    end
  end
end
