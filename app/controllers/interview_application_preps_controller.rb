# frozen_string_literal: true

class InterviewApplicationPrepsController < ApplicationController
  before_action :set_application

  # POST /interview_applications/:interview_application_id/prep/refresh
  def refresh
    ent = Billing::Entitlements.for(Current.user)
    unless ent.allowed?(:interview_prepare_access)
      redirect_to interview_application_path(@application, tab: "prepare"),
        alert: "Upgrade to unlock full Prepare",
        status: :see_other
      return
    end

    remaining = ent.remaining(:interview_prepare_refreshes)
    if remaining.is_a?(Integer) && remaining <= 0
      redirect_to interview_application_path(@application, tab: "prepare"),
        alert: "You’ve reached your monthly refresh limit",
        status: :see_other
      return
    end

    GenerateInterviewPrepPackJob.perform_later(@application, user: Current.user)

    redirect_to interview_application_path(@application, tab: "prepare"),
      notice: "Generating prep…",
      status: :see_other
  end

  private

  def set_application
    @application = Current.user.interview_applications.not_deleted.find(params[:interview_application_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Application not found"
  end
end
