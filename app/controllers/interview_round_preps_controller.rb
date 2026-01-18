# frozen_string_literal: true

# Controller for managing interview round preparation content
class InterviewRoundPrepsController < ApplicationController
  before_action :set_application
  before_action :set_round

  # GET /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/prep
  # Shows the prep content for a specific round
  def show
    @prep = @round.prep
    @entitlements = Billing::Entitlements.for(Current.user)
  end

  # POST /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/prep/generate
  # Generates or regenerates prep content for a round
  def generate
    ent = Billing::Entitlements.for(Current.user)

    # Check access
    unless ent.allowed?(:round_prep_access)
      redirect_to interview_application_path(@application, anchor: "rounds"),
        alert: "Round prep requires a Pro or Sprint subscription."
      return
    end

    # Check quota
    remaining = ent.remaining(:round_prep_generations)
    if remaining.is_a?(Integer) && remaining <= 0
      redirect_to interview_application_path(@application, anchor: "rounds"),
        alert: "You've used all your round prep generations for this month."
      return
    end

    @artifact = InterviewRoundPrepArtifact.find_or_initialize_for(
      interview_round: @round,
      kind: :comprehensive
    )

    # Enqueue the job for background generation
    GenerateRoundPrepJob.perform_later(@round)

    respond_to do |format|
      format.html do
        redirect_to interview_application_path(@application, anchor: "rounds"),
          notice: "Generating interview prep for #{@round.stage_display_name}..."
      end
      format.turbo_stream do
        flash.now[:notice] = "Generating interview prep..."
      end
    end
  end

  # GET /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/prep/status
  # Returns the current generation status (for polling)
  def status
    @artifact = @round.prep_artifacts.find_by(kind: :comprehensive)

    respond_to do |format|
      format.json do
        render json: {
          status: @artifact&.status || "not_started",
          generated_at: @artifact&.generated_at,
          has_content: @artifact&.has_content?
        }
      end
      format.turbo_stream
    end
  end

  private

  def set_application
    @application = Current.user.interview_applications.find(params[:interview_application_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Application not found"
  end

  def set_round
    @round = @application.interview_rounds.find(params[:interview_round_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_application_path(@application), alert: "Interview round not found"
  end
end
