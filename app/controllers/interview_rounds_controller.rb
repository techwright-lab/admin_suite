# frozen_string_literal: true

# Controller for managing interview rounds within an application
class InterviewRoundsController < ApplicationController
  before_action :set_application
  before_action :set_round, only: [ :show, :edit, :update, :destroy ]

  # GET /interview_applications/:interview_application_id/interview_rounds
  def index
    @rounds = @application.interview_rounds.ordered
  end

  # GET /interview_applications/:interview_application_id/interview_rounds/:id
  def show
  end

  # GET /interview_applications/:interview_application_id/interview_rounds/new
  def new
    @round = @application.interview_rounds.build(position: @application.interview_rounds.count + 1)
  end

  # GET /interview_applications/:interview_application_id/interview_rounds/:id/edit
  def edit
  end

  # POST /interview_applications/:interview_application_id/interview_rounds
  def create
    @round = @application.interview_rounds.build(round_params)

    if @round.save
      respond_to do |format|
        format.html { redirect_to interview_application_path(@application), notice: "Interview round added successfully!" }
        format.turbo_stream { flash.now[:notice] = "Interview round added successfully!" }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /interview_applications/:interview_application_id/interview_rounds/:id
  def update
    previously_completed = @round.completed_at.present?

    if @round.update(round_params)
      maybe_unlock_insight_trial_after_second_completion(previously_completed: previously_completed)
      respond_to do |format|
        format.html { redirect_to interview_application_path(@application), notice: "Interview round updated successfully!" }
        format.turbo_stream { flash.now[:notice] = "Interview round updated successfully!" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /interview_applications/:interview_application_id/interview_rounds/:id
  def destroy
    @round.destroy

    respond_to do |format|
      format.html { redirect_to interview_application_path(@application), notice: "Interview round deleted successfully!", status: :see_other }
      format.turbo_stream { flash.now[:notice] = "Interview round deleted successfully!" }
    end
  end

  private

  def set_application
    @application = Current.user.interview_applications.find(params[:interview_application_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Application not found"
  end

  def set_round
    @round = @application.interview_rounds.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_application_path(@application), alert: "Interview round not found"
  end

  def round_params
    params.expect(interview_round: [
      :stage,
      :stage_name,
      :scheduled_at,
      :completed_at,
      :duration_minutes,
      :interviewer_name,
      :interviewer_role,
      :notes,
      :result,
      :position,
      :interview_round_type_id
    ])
  end

  # Unlocks the insight-triggered trial when the user completes their 2nd interview round.
  #
  # @param previously_completed [Boolean]
  # @return [void]
  def maybe_unlock_insight_trial_after_second_completion(previously_completed:)
    return if previously_completed
    return unless @round.completed_at.present?

    user = Current.user
    return if user.nil?

    completed_count = user.interview_rounds.completed.count
    return unless completed_count == 2

    Billing::TrialUnlockService.new(
      user: user,
      trigger: :second_interview_completed,
      metadata: { completed_count: completed_count, interview_round_id: @round.id }
    ).run
  end
end
