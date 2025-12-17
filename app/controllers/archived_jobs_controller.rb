# frozen_string_literal: true

class ArchivedJobsController < ApplicationController
  # GET /archived_jobs
  def index
    @archived_opportunities = Current.user.opportunities.archived
      .order(archived_at: :desc)

    @archived_saved_jobs = Current.user.saved_jobs.archived
      .includes(:opportunity)
      .order(archived_at: :desc)
  end
end



