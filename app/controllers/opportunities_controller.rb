# frozen_string_literal: true

# Controller for managing job opportunities from recruiter outreach
# Presents opportunities in a stacked-cards UI with Apply/Ignore actions
class OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: [ :show, :apply, :ignore, :restore, :update_url ]

  # GET /opportunities
  #
  # Main opportunities view with stacked cards layout
  def index
    load_opportunity_stack(selected_id: params[:opportunity_id].presence&.to_i)

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("opportunities_stack", partial: "opportunities/stack"),
          turbo_stream.update("opportunities_count", html: opportunities_count_badge)
        ]
      end
    end
  end

  # GET /opportunities/:id
  #
  # Show full opportunity details
  def show
    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "opportunity_detail",
          partial: "opportunities/card",
          locals: { opportunity: @opportunity, show_actions: true }
        )
      end
    end
  end

  # POST /opportunities/:id/apply
  #
  # Creates an InterviewApplication from the opportunity
  def apply
    service = Opportunities::CreateApplicationService.new(@opportunity, Current.user)
    result = service.call

    respond_to do |format|
      if result[:success]
        format.html do
          redirect_to result[:application],
            notice: "Application created for #{result[:company].name}!"
        end
        format.turbo_stream do
          load_opportunity_stack

          render turbo_stream: [
            turbo_stream.update("opportunities_stack", partial: "opportunities/stack"),
            turbo_stream.update("opportunities_count", html: opportunities_count_badge)
          ]
        end
        format.json { render json: { success: true, application_id: result[:application].id } }
      else
        format.html do
          redirect_to opportunities_path,
            alert: result[:error] || "Could not create application."
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: result[:error] } }
          )
        end
        format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
      end
    end
  end

  # POST /opportunities/:id/ignore
  #
  # Marks the opportunity as ignored and shows the next one
  def ignore
    if @opportunity.archive_as_ignored!
      respond_to do |format|
        format.html { redirect_to opportunities_path, notice: "Opportunity ignored." }
        format.turbo_stream do
          load_opportunity_stack

          render turbo_stream: [
            turbo_stream.update("opportunities_stack", partial: "opportunities/stack"),
            turbo_stream.update("opportunities_count", html: opportunities_count_badge)
          ]
        end
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to opportunities_path, alert: "Could not ignore opportunity." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: "Could not ignore opportunity." } }
          )
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  # POST /opportunities/:id/restore
  #
  # Restores an archived opportunity back to the stack
  def restore
    if @opportunity.reconsider!
      respond_to do |format|
        format.html { redirect_to opportunities_path, notice: "Opportunity restored." }
        format.turbo_stream do
          load_opportunity_stack(selected_id: @opportunity.id)

          render turbo_stream: [
            turbo_stream.update("opportunities_stack", partial: "opportunities/stack"),
            turbo_stream.update("opportunities_count", html: opportunities_count_badge)
          ]
        end
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to opportunities_path, alert: "Could not restore opportunity." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: "Could not restore opportunity." } }
          )
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /opportunities/:id/update_url
  #
  # Updates the job URL for manual entry
  def update_url
    if @opportunity.update(job_url: params[:job_url])
      # Optionally trigger extraction if URL changed
      if @opportunity.job_url.present? && @opportunity.saved_change_to_job_url?
        ProcessOpportunityEmailJob.perform_later(@opportunity.id)
      end

      respond_to do |format|
        format.html { redirect_to opportunity_path(@opportunity), notice: "URL updated." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "opportunity_card_#{@opportunity.id}",
            partial: "opportunities/card",
            locals: { opportunity: @opportunity, show_actions: true }
          )
        end
        format.json { render json: { success: true, job_url: @opportunity.job_url } }
      end
    else
      respond_to do |format|
        format.html { redirect_to opportunity_path(@opportunity), alert: "Could not update URL." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "flash",
            partial: "shared/flash",
            locals: { flash: { alert: "Could not update URL." } }
          )
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  private

  # Sets the opportunity for member actions
  #
  # @return [Opportunity]
  def set_opportunity
    @opportunity = current_user_opportunities.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to opportunities_path, alert: "Opportunity not found." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "shared/flash",
          locals: { flash: { alert: "Opportunity not found." } }
        )
      end
      format.json { render json: { error: "Not found" }, status: :not_found }
    end
  end

  # Returns the current user's opportunities
  #
  # @return [ActiveRecord::Relation]
  def current_user_opportunities
    Current.user.opportunities
  end

  # Returns HTML for the opportunities count badge
  #
  # @return [String]
  def opportunities_count_badge
    count = actionable_unsaved_opportunities.count
    return "" if count == 0

    helpers.content_tag(:span, count,
      class: "ml-auto inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-400"
    )
  end

  def actionable_unsaved_opportunities
    current_user_opportunities
      .actionable
      .left_outer_joins(:saved_job)
      .where("saved_jobs.id IS NULL OR saved_jobs.status = 'archived'")
  end

  def load_opportunity_stack(selected_id: nil)
    @opportunities = actionable_unsaved_opportunities
      .includes(:synced_email)
      .recent

    @current_opportunity = if selected_id
      @opportunities.detect { |o| o.id == selected_id } || @opportunities.first
    else
      @opportunities.first
    end

    if @current_opportunity
      ids = @opportunities.map(&:id)
      idx = ids.index(@current_opportunity.id) || 0

      @current_position = idx + 1
      @total_count = ids.length
      @prev_opportunity_id = idx.positive? ? ids[idx - 1] : nil
      @next_opportunity_id = (idx + 1) < ids.length ? ids[idx + 1] : nil
      @remaining_count = ids.length - @current_position
    else
      @current_position = 0
      @total_count = 0
      @prev_opportunity_id = nil
      @next_opportunity_id = nil
      @remaining_count = nil
    end
  end

  # Strong parameters for opportunity updates
  #
  # @return [ActionController::Parameters]
  def opportunity_params
    params.expect(opportunity: [ :job_url ])
  end
end
