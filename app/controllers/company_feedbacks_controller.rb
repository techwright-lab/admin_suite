# frozen_string_literal: true

# Controller for managing company feedback for interview applications
class CompanyFeedbacksController < ApplicationController
  before_action :set_application
  before_action :set_feedback, only: [:show, :edit, :update, :destroy]

  # GET /interview_applications/:interview_application_id/company_feedback
  def show
  end

  # GET /interview_applications/:interview_application_id/company_feedback/new
  def new
    @feedback = @application.build_company_feedback
  end

  # GET /interview_applications/:interview_application_id/company_feedback/edit
  def edit
  end

  # POST /interview_applications/:interview_application_id/company_feedback
  def create
    @feedback = @application.build_company_feedback(feedback_params)

    if @feedback.save
      respond_to do |format|
        format.html { redirect_to interview_application_path(@application), notice: "Company feedback added successfully!" }
        format.turbo_stream { flash.now[:notice] = "Company feedback added successfully!" }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /interview_applications/:interview_application_id/company_feedback
  def update
    if @feedback.update(feedback_params)
      respond_to do |format|
        format.html { redirect_to interview_application_path(@application), notice: "Company feedback updated successfully!" }
        format.turbo_stream { flash.now[:notice] = "Company feedback updated successfully!" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /interview_applications/:interview_application_id/company_feedback
  def destroy
    @feedback.destroy

    respond_to do |format|
      format.html { redirect_to interview_application_path(@application), notice: "Company feedback deleted successfully!", status: :see_other }
      format.turbo_stream { flash.now[:notice] = "Company feedback deleted successfully!" }
    end
  end

  private

  def set_application
    @application = Current.user.interview_applications.find(params[:interview_application_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Application not found"
  end

  def set_feedback
    @feedback = @application.company_feedback
    redirect_to interview_application_path(@application), alert: "Feedback not found" if @feedback.nil?
  end

  def feedback_params
    params.expect(company_feedback: [
      :feedback_text,
      :received_at,
      :rejection_reason,
      :next_steps,
      :self_reflection
    ])
  end
end

