# frozen_string_literal: true

# Controller for managing interview application tracking
class InterviewApplicationsController < ApplicationController
  before_action :set_application, only: [ :show, :edit, :update, :update_pipeline_stage, :update_job_description, :archive, :reject, :accept, :reactivate ]
  before_action :set_application_for_soft_delete, only: [ :destroy ]
  before_action :set_deleted_application, only: [ :restore ]
  before_action :set_view_preference, only: [ :index, :kanban ]

  # GET /interview_applications
  def index
    scope = Current.user.interview_applications

    @status_counts = scope.not_deleted.group(:status).count
    @deleted_count = scope.deleted.count

    base_applications = scope
      .includes(:company, :job_role, :job_listing, :skill_tags, :interview_rounds)

    if params[:status] == "deleted"
      base_applications = base_applications.deleted
    else
      base_applications = base_applications.not_deleted
      base_applications = base_applications.where(status: params[:status]) if params[:status].present?
    end

    # Apply search
    if params[:q].present?
      search_term = "%#{params[:q].strip}%"
      base_applications = base_applications
        .left_outer_joins(:company, :job_role)
        .where(
          "companies.name ILIKE :q OR job_roles.title ILIKE :q",
          q: search_term
        )
    end

    # Apply filters
    base_applications = base_applications.where(pipeline_stage: params[:pipeline_stage]) if params[:pipeline_stage].present?

    if params[:date_from].present?
      begin
        base_applications = base_applications.where("applied_at >= ?", Date.parse(params[:date_from]))
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end

    if params[:date_to].present?
      begin
        base_applications = base_applications.where("applied_at <= ?", Date.parse(params[:date_to]))
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end

    # Apply sorting
    case params[:sort]
    when "company"
      base_applications = base_applications.joins(:company).order("companies.name ASC")
    when "company_desc"
      base_applications = base_applications.joins(:company).order("companies.name DESC")
    when "role"
      base_applications = base_applications.joins(:job_role).order("job_roles.title ASC")
    when "role_desc"
      base_applications = base_applications.joins(:job_role).order("job_roles.title DESC")
    when "date"
      base_applications = base_applications.order("applied_at ASC, created_at ASC")
    when "date_desc"
      base_applications = base_applications.order("applied_at DESC, created_at DESC")
    else
      base_applications = base_applications.recent
    end

    # Paginate for table view, load all for kanban
    if @current_view == "kanban"
      @applications = base_applications.to_a
      # Group by pipeline stage for kanban columns
      @applications_by_pipeline_stage = InterviewApplication::PIPELINE_STAGES.index_with do |stage|
        @applications.select { |app| app.pipeline_stage == stage.to_s }
      end
    else
      @pagy, @applications = pagy(base_applications, limit: 20)
    end
  end

  # GET /interview_applications/kanban
  def kanban
    @applications = Current.user.interview_applications
      .includes(:company, :job_role, :interview_rounds)
      .not_deleted
      .active
      .recent

    @applications_by_pipeline_stage = InterviewApplication::PIPELINE_STAGES.index_with do |stage|
      @applications.select { |app| app.pipeline_stage == stage.to_s }
    end
  end

  # GET /interview_applications/:id
  def show
    @interview_rounds = @application.interview_rounds.ordered
    @next_upcoming_round = @application.interview_rounds.upcoming.order(scheduled_at: :asc).first
    @company_feedback = @application.company_feedback
    @synced_emails = @application.synced_emails.recent
    @application_timeline = ApplicationTimelineService.new(@application)
    @extracted_company_careers_url = @synced_emails
      .find { |email| email.signal_company_careers_url.present? }
      &.signal_company_careers_url
    @extracted_action_links = build_extracted_action_links(@synced_emails)
    @join_interview_link = build_join_interview_link(@next_upcoming_round, @extracted_action_links)
    @reschedule_link = build_reschedule_link(@extracted_action_links)

    @prep_artifacts_by_kind = @application.interview_prep_artifacts.recent_first.index_by(&:kind)
    focus = @prep_artifacts_by_kind["focus_areas"]&.content
    focus_items = Array(focus&.dig("focus_areas")).filter_map { |i| i.is_a?(Hash) ? i["title"] : nil }
    @prep_focus_areas_preview = focus_items.first(3)
  end

  # GET /interview_applications/new
  def new
    @application = Current.user.interview_applications.build
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # GET /interview_applications/:id/edit
  def edit
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # POST /interview_applications
  def create
    @application = Current.user.interview_applications.build(application_params)

    # Set defaults (AASM will set initial states, but we ensure applied_at is set)
    @application.applied_at ||= Date.today

    if @application.save
      # Create job listing from URL if provided
      if params[:interview_application][:job_listing_url].present?
        CreateJobListingFromUrlService.new(@application, params[:interview_application][:job_listing_url]).call
      end

      respond_to do |format|
        format.html { redirect_to interview_applications_path, notice: "Application added successfully!" }
        format.turbo_stream { redirect_to interview_applications_path, notice: "Application added successfully!", status: :see_other }
      end
    else
      @companies = Company.alphabetical.limit(100)
      @job_roles = JobRole.alphabetical.limit(100)
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /interview_applications/:id
  def update
    if @application.update(application_params)
      redirect_to interview_applications_path, notice: "Application updated successfully!"
    else
      @companies = Company.alphabetical.limit(100)
      @job_roles = JobRole.alphabetical.limit(100)
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /interview_applications/:id/update_job_description
  def update_job_description
    if @application.update(job_description_params)
      redirect_to interview_application_path(@application, tab: "prepare"),
        notice: "Job description saved",
        status: :see_other
    else
      redirect_to interview_application_path(@application, tab: "prepare"),
        alert: "Could not save job description",
        status: :see_other
    end
  end

  # DELETE /interview_applications/:id
  def destroy
    if @application.soft_delete!
      notice = "Application deleted. You can restore it within 3 months."

      # If the delete happened from the show page, redirecting back would hit a now-unreachable URL.
      if request.referer&.match?(%r{/applications/[^/?]+$})
        redirect_to interview_applications_path, notice:, status: :see_other
      else
        redirect_back fallback_location: interview_applications_path, notice:, status: :see_other
      end
    else
      redirect_back fallback_location: interview_application_path(@application), alert: "Could not delete application", status: :see_other
    end
  end

  # PATCH /interview_applications/:id/update_pipeline_stage
  def update_pipeline_stage
    target_stage = params[:pipeline_stage]&.to_sym

    # Map target stage to appropriate AASM event
    event_method = case target_stage
    when :screening
      :move_to_screening
    when :interviewing
      :move_to_interviewing
    when :offer
      :move_to_offer
    when :closed
      :move_to_closed
    when :applied
      :move_to_applied
    else
      nil
    end

    if event_method && @application.aasm(:pipeline_stage).may_fire_event?(event_method)
      if @application.send("#{event_method}!")
        respond_to do |format|
          format.html { redirect_to interview_applications_path }
          format.turbo_stream
          format.json { render json: { success: true, pipeline_stage: @application.pipeline_stage } }
        end
      else
        respond_to do |format|
          format.html { redirect_to interview_applications_path, alert: "Failed to update stage" }
          format.json { render json: { success: false, errors: @application.errors }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to interview_applications_path, alert: "Invalid stage transition" }
        format.json { render json: { success: false, errors: [ "Invalid stage transition" ] }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /interview_applications/:id/archive
  def archive
    if @application.may_archive? && @application.archive!
      redirect_back fallback_location: interview_application_path(@application), notice: "Application archived", status: :see_other
    else
      redirect_back fallback_location: interview_application_path(@application), alert: "Cannot archive this application", status: :see_other
    end
  end

  # PATCH /interview_applications/:id/reject
  def reject
    if @application.may_reject? && @application.reject!
      redirect_back fallback_location: interview_application_path(@application), notice: "Application marked as rejected", status: :see_other
    else
      redirect_back fallback_location: interview_application_path(@application), alert: "Cannot reject this application", status: :see_other
    end
  end

  # PATCH /interview_applications/:id/accept
  def accept
    if @application.may_accept? && @application.accept!
      redirect_back fallback_location: interview_application_path(@application), notice: "Congratulations! Application marked as accepted", status: :see_other
    else
      redirect_back fallback_location: interview_application_path(@application), alert: "Cannot accept this application", status: :see_other
    end
  end

  # PATCH /interview_applications/:id/reactivate
  def reactivate
    if @application.may_reactivate? && @application.reactivate!
      redirect_back fallback_location: interview_application_path(@application), notice: "Application reactivated", status: :see_other
    else
      redirect_back fallback_location: interview_application_path(@application), alert: "Cannot reactivate this application", status: :see_other
    end
  end

  # PATCH /interview_applications/:id/restore
  def restore
    if @application.restore!
      redirect_back fallback_location: interview_applications_path, notice: "Application restored", status: :see_other
    else
      redirect_back fallback_location: interview_applications_path(status: "deleted"), alert: "Could not restore application", status: :see_other
    end
  end

  # POST /interview_applications/quick_apply
  def quick_apply
    url = params[:url]&.strip

    if url.blank?
      respond_to do |format|
        format.json { render json: { success: false, error: "URL is required" }, status: :unprocessable_entity }
        format.html { redirect_to interview_applications_path, alert: "URL is required" }
      end
      return
    end

    service = QuickApplyFromUrlService.new(url, Current.user)
    result = service.call

    if result[:success]
      application = result[:application]

      respond_to do |format|
        format.json do
          render json: {
            success: true,
            application: {
              id: application.id,
              slug: application.slug,
              company_name: application.company.name,
              job_role_title: application.job_role.title,
              url: interview_application_path(application)
            },
            message: "Application created successfully!"
          }
        end
        format.html do
          redirect_to interview_application_path(application), notice: "Application created successfully!"
        end
        format.turbo_stream do
          flash.now[:notice] = "Application created successfully!"
          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.redirect_to(interview_application_path(application))
          ]
        end
      end
    else
      error_message = result[:error] || "Failed to create application"

      respond_to do |format|
        format.json do
          render json: {
            success: false,
            error: error_message
          }, status: :unprocessable_entity
        end
        format.html do
          redirect_to interview_applications_path, alert: error_message
        end
        format.turbo_stream do
          flash.now[:alert] = error_message
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        end
      end
    end
  rescue => e
    Rails.logger.error("Quick apply failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    respond_to do |format|
      format.json do
        render json: {
          success: false,
          error: "An error occurred: #{e.message}"
        }, status: :internal_server_error
      end
      format.html do
        redirect_to interview_applications_path, alert: "An error occurred. Please try again."
      end
      format.turbo_stream do
        flash.now[:alert] = "An error occurred. Please try again."
        render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
      end
    end
  end

  private

  # Builds a de-duplicated list of action links extracted from emails
  #
  # @param emails [Enumerable<SyncedEmail>]
  # @return [Array<Hash>]
  def build_extracted_action_links(emails)
    require "set"
    seen = Set.new

    Array(emails).flat_map(&:action_links).each_with_object([]) do |link, links|
      url = link["url"].to_s.strip
      next if url.blank? || seen.include?(url)

      seen.add(url)
      links << link
    end
  end

  # Picks a join interview link from rounds or extracted links
  #
  # @param next_round [InterviewRound, nil]
  # @param links [Array<Hash>]
  # @return [String, nil]
  def build_join_interview_link(next_round, links)
    return next_round.video_link if next_round&.video_link.present?

    join_link = links.find do |link|
      label = link["action_label"].to_s.downcase
      label.include?("join") || label.include?("zoom") || label.include?("meet")
    end

    join_link&.dig("url")
  end

  # Picks a reschedule/scheduling link from extracted links
  #
  # @param links [Array<Hash>]
  # @return [String, nil]
  def build_reschedule_link(links)
    link = links.find do |item|
      label = item["action_label"].to_s.downcase
      label.include?("reschedule") || label.include?("schedule") || label.include?("book")
    end

    link&.dig("url")
  end

  def set_application
    @application = Current.user.interview_applications.not_deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Application not found"
  end

  def set_application_for_soft_delete
    @application = Current.user.interview_applications.not_deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path, alert: "Application not found"
  end

  def set_deleted_application
    @application = Current.user.interview_applications.deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to interview_applications_path(status: "deleted"), alert: "Deleted application not found"
  end

  def set_view_preference
    # Get view from params or user preference
    view = params[:view] || Current.user.preference.preferred_view
    # Normalize view names: "list" -> "table"
    @current_view = (view == "list") ? "table" : view
    @current_view = "table" if params[:status] == "deleted"
  end

  def application_params
    params.expect(interview_application: [
      :company_id,
      :job_role_id,
      :applied_at,
      :notes,
      :job_description_text
    ])
  end

  def job_description_params
    params.expect(interview_application: [ :job_description_text ])
  end
end
