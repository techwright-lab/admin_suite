# frozen_string_literal: true

# Controller for managing self-reflection feedback for interview rounds
class InterviewFeedbacksController < ApplicationController
  before_action :set_interview_round
  before_action :set_interview_feedback, only: [ :edit, :update, :destroy ]

  # GET /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/interview_feedback/new
  def new
    @feedback = @round.interview_feedback || @round.build_interview_feedback
  end

  # POST /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/interview_feedback
  def create
    @feedback = @round.build_interview_feedback(feedback_params)

    if @feedback.save
      trial_result = maybe_unlock_insight_trial_after_feedback
      notice = "Self-reflection added successfully!"
      if trial_result[:unlocked]
        notice = "#{notice} You’ve unlocked Pro insights for 72 hours."
      end
      redirect_to interview_application_path(@round.interview_application), notice: notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/interview_feedback/edit
  def edit
  end

  # PATCH/PUT /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/interview_feedback
  def update
    if @feedback.update(feedback_params)
      redirect_to interview_application_path(@round.interview_application), notice: "Self-reflection updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /interview_applications/:interview_application_id/interview_rounds/:interview_round_id/interview_feedback
  def destroy
    @feedback.destroy
    redirect_to interview_application_path(@round.interview_application), notice: "Self-reflection deleted successfully!"
  end

  private

  def set_interview_round
    @round = Current.user.interview_applications
      .find(params[:interview_application_id])
      .interview_rounds
      .find(params[:interview_round_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Interview round not found"
  end

  def set_interview_feedback
    @feedback = @round.interview_feedback
    redirect_to interview_application_path(@round.interview_application), alert: "Self-reflection not found" unless @feedback
  end

  def feedback_params
    params.require(:interview_feedback).permit(
      :went_well,
      :to_improve,
      :self_reflection,
      :interviewer_notes,
      :tag_list
    )
  end

  # Unlocks the insight-triggered trial when the user has uploaded a CV and is adding their first feedback entry.
  #
  # @return [Hash] Trial unlock result
  def maybe_unlock_insight_trial_after_feedback
    user = Current.user
    return { unlocked: false } if user.nil?
    return { unlocked: false } unless user.user_resumes.exists?

    feedback_count = InterviewFeedback
      .joins(interview_round: { interview_application: :user })
      .where(users: { id: user.id })
      .count
    return { unlocked: false } unless feedback_count == 1

    Billing::TrialUnlockService.new(
      user: user,
      trigger: :first_feedback_after_cv,
      metadata: { feedback_count: feedback_count }
    ).run
  end
end
