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
      redirect_to interview_application_path(@round.interview_application), notice: "Self-reflection added successfully!"
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
end
