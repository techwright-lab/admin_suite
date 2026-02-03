# frozen_string_literal: true

# Controller for the Signals view (rebranded Inbox)
# Displays synced emails with AI-extracted intelligence and smart actions
# Supports split-pane layout with Turbo Frames
class SignalsController < ApplicationController
  before_action :set_synced_email, only: [ :show, :match_application, :ignore, :execute_action ]

  # GET /signals
  #
  # Main signals view with split-pane layout
  def index
    @emails = current_user_emails
      .includes(:interview_application, :email_sender, interview_application: [ :company, :job_role ])
      .order(email_date: :desc)

    # Apply relevance filter (default to relevant emails only)
    @current_relevance = params[:relevance] || "relevant"
    @emails = filter_by_relevance(@emails)

    # Apply other filters
    @emails = filter_by_type(@emails)
    @emails = filter_by_status(@emails)
    @emails = filter_by_company(@emails)
    @emails = search_emails(@emails)

    # For "all" tab, show unified chronological list; otherwise split by matched/unmatched
    @show_unified_list = @current_relevance == "all"

    if @show_unified_list
      # Unified chronological list - group by thread and paginate all together
      all_by_thread = group_emails_by_thread(@emails)
      @pagy_all, @all_emails = pagy_array(all_by_thread, limit: 20, page_param: :page)
      @grouped_emails = {}
      @unmatched_emails = []
      @pagy_unmatched = nil
    else
      # Split view: unmatched emails first, then matched grouped by application
      @grouped_emails = group_emails_by_application(@emails)

      # Get unmatched emails grouped by thread (only latest email per thread)
      unmatched_by_thread = group_emails_by_thread(@emails.unmatched)
      @pagy_unmatched, @unmatched_emails = pagy_array(unmatched_by_thread, limit: 15, page_param: :unmatched_page)
      @all_emails = []
      @pagy_all = nil
    end

    # Load filter options
    @email_types = SyncedEmail::EMAIL_TYPES
    @companies = Company.joins(:interview_applications)
      .where(interview_applications: { user_id: Current.user.id })
      .distinct
      .alphabetical

    # Calculate counts for relevance tabs
    @relevance_counts = calculate_relevance_counts

    # If email_id param, pre-select that email
    @selected_email = current_user_emails.find_by(id: params[:email_id]) if params[:email_id]

    # Respond to turbo frame requests for email_list (search/filter without full page reload)
    respond_to do |format|
      format.html do
        if turbo_frame_request_id == "email_list"
          render inline: <<~ERB, locals: { grouped_emails: @grouped_emails, unmatched_emails: @unmatched_emails, pagy_unmatched: @pagy_unmatched, selected_email_id: @selected_email&.id, show_unified_list: @show_unified_list, all_emails: @all_emails, pagy_all: @pagy_all }
            <%= turbo_frame_tag "email_list", class: "flex-1 overflow-y-auto" do %>
              <%= render "signals/email_list", grouped_emails: grouped_emails, unmatched_emails: unmatched_emails, pagy_unmatched: pagy_unmatched, selected_email_id: selected_email_id, show_unified_list: show_unified_list, all_emails: all_emails, pagy_all: pagy_all %>
            <% end %>
          ERB
        else
          render :index
        end
      end
    end
  end

  # GET /signals/:id
  #
  # Show email detail with extracted signals - responds to Turbo Frame for split-pane
  def show
    @application = @email.interview_application
    @thread_emails = @email.thread_emails.includes(:email_sender)

    respond_to do |format|
      format.html do
        # Full page render for direct access or mobile
        render :show
      end
      format.turbo_stream do
        # Turbo Frame update for split-pane
        render turbo_stream: turbo_stream.update(
          "email_detail",
          partial: "signals/detail_panel",
          locals: { email: @email, thread_emails: @thread_emails, application: @application }
        )
      end
    end
  end

  # GET /signals/application_emails
  #
  # Turbo Frame endpoint used to progressively load matched emails (latest per thread)
  # for a single interview application group in the Signals list.
  #
  # Params:
  # - interview_application_id (required)
  # - limit (optional, defaults to 5; increases in batches of 5)
  # - plus any existing list filters (relevance, type, status, company_id, q)
  def application_emails
    application = Current.user.interview_applications.find(params[:interview_application_id])

    limit = params[:limit].to_i
    limit = 5 if limit <= 0
    limit = [ limit, 50 ].min

    emails = current_user_emails
      .includes(:interview_application, :email_sender, interview_application: [ :company, :job_role ])
      .order(email_date: :desc)

    @current_relevance = params[:relevance] || "relevant"
    emails = filter_by_relevance(emails)
    emails = filter_by_type(emails)
    emails = filter_by_status(emails)
    emails = filter_by_company(emails)
    emails = search_emails(emails)

    emails = emails
      .matched
      .where(interview_application_id: application.id)

    # Match the list behavior: show only the latest email per thread.
    unique_threads = {}
    emails.each do |email|
      thread_key = email.thread_id || email.id
      if unique_threads[thread_key].nil? || (email.email_date && email.email_date > unique_threads[thread_key].email_date)
        unique_threads[thread_key] = email
      end
    end

    thread_emails = unique_threads.values
      .sort_by { |e| e.email_date || e.created_at }
      .reverse

    frame_id = "signals_application_#{application.id}_emails"

    render inline: <<~ERB, locals: { application: application, emails: thread_emails, limit: limit, frame_id: frame_id, selected_email_id: params[:selected_email_id].presence&.to_i }
      <%= turbo_frame_tag frame_id do %>
        <%= render "signals/application_emails", application: application, emails: emails, limit: limit, frame_id: frame_id, selected_email_id: selected_email_id %>
      <% end %>
    ERB
  end

  # PATCH /signals/:id/match_application
  #
  # Match email to an interview application
  def match_application
    application = Current.user.interview_applications.find_by(id: params[:application_id])

    if application && @email.match_to_application!(application)
      # Also match other emails in the same thread
      match_thread_emails(application) if @email.thread_id.present?

      # Reprocess this email now that it is matched
      Signals::EmailStateOrchestrator.new(@email).call

      respond_to do |format|
        format.html { redirect_to signals_path, notice: "Signal matched to #{application.company.name}." }
        format.turbo_stream do
          flash.now[:notice] = "Signal matched to #{application.company.name}."
          @thread_emails = @email.thread_emails.includes(:email_sender)
          reload_email_list_data
          render turbo_stream: [
            turbo_stream.update("email_detail",
              partial: "signals/detail_panel",
              locals: { email: @email, thread_emails: @thread_emails, application: application }
            ),
            turbo_stream.update("email_list",
              partial: "signals/email_list",
              locals: { grouped_emails: @grouped_emails, unmatched_emails: @unmatched_emails, pagy_unmatched: @pagy_unmatched, selected_email_id: @email.id }
            ),
            turbo_stream.update("flash",
              partial: "shared/flash"
            ),
            turbo_stream.update("email_stats",
              html: email_stats_html
            )
          ]
        end
        format.json { render json: { success: true, application_id: application.id } }
      end
    else
      respond_to do |format|
        format.html { redirect_to signals_path, alert: "Could not match signal to application." }
        format.turbo_stream do
          flash.now[:alert] = "Could not match signal to application."
          render turbo_stream: [
            turbo_stream.update("email_detail",
              html: "<div class='p-4 text-red-600'>Could not match signal</div>"
            ),
            turbo_stream.update("flash",
              partial: "shared/flash"
            )
          ]
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /signals/:id/ignore
  #
  # Mark email as not interview-related
  def ignore
    if @email.ignore!
      respond_to do |format|
        format.html { redirect_to signals_path, notice: "Signal dismissed." }
        format.turbo_stream do
          state = reload_email_list_data_from_referer
          render turbo_stream: [
            turbo_stream.update("email_detail",
              partial: "signals/empty_state"
            ),
            turbo_stream.update("email_list",
              partial: "signals/email_list",
              locals: {
                grouped_emails: state[:grouped_emails],
                unmatched_emails: state[:unmatched_emails],
                pagy_unmatched: state[:pagy_unmatched],
                selected_email_id: nil,
                show_unified_list: state[:show_unified_list],
                all_emails: state[:all_emails],
                pagy_all: state[:pagy_all]
              }
            ),
            turbo_stream.update("email_stats",
              html: email_stats_html
            )
          ]
        end
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to signals_path, alert: "Could not dismiss signal." }
        format.turbo_stream do
          @thread_emails = @email.thread_emails.includes(:email_sender)
          render turbo_stream: turbo_stream.update(
            "email_detail",
            partial: "signals/detail_panel",
            locals: { email: @email, thread_emails: @thread_emails, application: @email.interview_application }
          )
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  # POST /signals/:id/execute_action
  #
  # Execute a signal action (start_application, schedule_interview, etc.)
  def execute_action
    action_type = params[:action_type]
    executor = Signals::ActionExecutor.new(@email, Current.user, action_type, params)
    result = executor.execute

    respond_to do |format|
      if result[:success]
        if result[:redirect_url]
          # External redirect (scheduling link, careers page, etc.)
          format.html { redirect_to result[:redirect_url], allow_other_host: result[:external] }
          format.turbo_stream do
            render turbo_stream: turbo_stream.action(:redirect, result[:redirect_url])
          end
          format.json { render json: result }
        elsif result[:redirect_path]
          # Internal redirect (new application page) - flash will show on target page
          flash[:notice] = result[:message]
          format.html { redirect_to result[:redirect_path], status: :see_other }
          format.turbo_stream { redirect_to result[:redirect_path], status: :see_other }
          format.json { render json: result }
        else
          # Action completed, refresh the view
          format.html { redirect_to signals_path, notice: result[:message] }
          format.turbo_stream do
            @thread_emails = @email.reload.thread_emails.includes(:email_sender)
            reload_email_list_data
            render turbo_stream: [
              turbo_stream.update("email_detail",
                partial: "signals/detail_panel",
                locals: { email: @email, thread_emails: @thread_emails, application: @email.interview_application }
              ),
              turbo_stream.update("email_list",
                partial: "signals/email_list",
                locals: { grouped_emails: @grouped_emails, unmatched_emails: @unmatched_emails, pagy_unmatched: @pagy_unmatched, selected_email_id: @email.id }
              ),
              turbo_stream.update("flash",
                partial: "shared/flash",
                locals: { notice: result[:message] }
              )
            ]
          end
          format.json { render json: result }
        end
      else
        format.html { redirect_to signal_path(@email), alert: result[:error] }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash",
            partial: "shared/flash",
            locals: { alert: result[:error] }
          )
        end
        format.json { render json: result, status: :unprocessable_entity }
      end
    end
  end

  private

  # Sets the email for member actions
  #
  # @return [SyncedEmail]
  def set_synced_email
    @email = current_user_emails.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to signals_path, alert: "Signal not found." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "email_detail",
          partial: "signals/empty_state"
        )
      end
    end
  end

  # Returns the current user's synced emails
  #
  # @return [ActiveRecord::Relation]
  def current_user_emails
    Current.user.synced_emails
  end

  # Filters emails by relevance (all, relevant, interviews, opportunities)
  #
  # @param emails [ActiveRecord::Relation]
  # @return [ActiveRecord::Relation]
  def filter_by_relevance(emails)
    case @current_relevance
    when "all"
      emails.visible  # Excludes ignored and auto_ignored
    when "interviews"
      emails.interview_related.visible
    when "opportunities"
      emails.potential_opportunities.visible
    else # "relevant" (default)
      emails.relevant
    end
  end

  # Calculates counts for relevance filter tabs
  #
  # @return [Hash] Counts by relevance type
  def calculate_relevance_counts
    base = current_user_emails
    {
      all: base.visible.count,
      relevant: base.relevant.count,
      interviews: base.interview_related.visible.count,
      opportunities: base.potential_opportunities.visible.count
    }
  end

  # Filters emails by type
  #
  # @param emails [ActiveRecord::Relation]
  # @return [ActiveRecord::Relation]
  def filter_by_type(emails)
    return emails unless params[:type].present?

    emails.by_type(params[:type])
  end

  # Filters emails by status (matched/unmatched/all)
  #
  # @param emails [ActiveRecord::Relation]
  # @return [ActiveRecord::Relation]
  def filter_by_status(emails)
    case params[:status]
    when "matched"
      emails.matched
    when "unmatched"
      emails.unmatched
    when "pending"
      emails.pending
    when "ignored"
      emails.ignored
    else
      emails
    end
  end

  # Filters emails by company
  #
  # @param emails [ActiveRecord::Relation]
  # @return [ActiveRecord::Relation]
  def filter_by_company(emails)
    return emails unless params[:company_id].present?

    company = Company.find_by(id: params[:company_id])
    return emails unless company

    application_ids = Current.user.interview_applications
      .where(company: company)
      .pluck(:id)

    emails.where(interview_application_id: application_ids)
  end

  # Searches emails by query
  #
  # @param emails [ActiveRecord::Relation]
  # @return [ActiveRecord::Relation]
  def search_emails(emails)
    return emails unless params[:q].present?

    query = "%#{params[:q]}%"
    emails.where(
      "subject ILIKE :q OR from_email ILIKE :q OR from_name ILIKE :q OR snippet ILIKE :q",
      q: query
    )
  end

  # Groups emails by their associated application
  # Returns the latest email from each thread grouped by application
  #
  # @param emails [ActiveRecord::Relation]
  # @return [Hash]
  def group_emails_by_application(emails)
    # Get unique threads, keeping only the latest email from each thread
    unique_threads = {}
    emails.matched.each do |email|
      thread_key = email.thread_id || email.id
      if unique_threads[thread_key].nil? || (email.email_date && email.email_date > unique_threads[thread_key].email_date)
        unique_threads[thread_key] = email
      end
    end

    # Group by application
    unique_threads.values
      .group_by(&:interview_application)
      .transform_values { |app_emails| app_emails.sort_by { |e| e.email_date || e.created_at }.reverse }
      .sort_by { |app, _| app&.company&.name || "" }
      .to_h
  end

  # Groups emails by thread, keeping only the latest email from each thread
  #
  # @param emails [ActiveRecord::Relation]
  # @return [Array<SyncedEmail>]
  def group_emails_by_thread(emails)
    unique_threads = {}
    emails.each do |email|
      thread_key = email.thread_id.presence || "single_#{email.id}"
      if unique_threads[thread_key].nil? || (email.email_date && email.email_date > unique_threads[thread_key].email_date)
        unique_threads[thread_key] = email
      end
    end

    unique_threads.values.sort_by { |e| e.email_date || e.created_at }.reverse
  end

  # Matches all emails in the same thread to an application
  #
  # @param application [InterviewApplication]
  # @return [void]
  def match_thread_emails(application)
    current_user_emails
      .where(thread_id: @email.thread_id)
      .where.not(id: @email.id)
      .update_all(interview_application_id: application.id, status: :processed)
  end

  # Reloads the email list data for Turbo Stream updates
  #
  # @return [void]
  def reload_email_list_data
    emails = current_user_emails
      .includes(:interview_application, :email_sender, interview_application: [ :company, :job_role ])
      .order(email_date: :desc)

    @grouped_emails = group_emails_by_application(emails)
    unmatched_by_thread = group_emails_by_thread(emails.unmatched)
    @pagy_unmatched, @unmatched_emails = pagy_array(unmatched_by_thread, limit: 15, page_param: :unmatched_page)
  end

  # Reloads the email list data using the Signals page query params.
  #
  # Turbo Stream actions like `ignore` are invoked from within the detail frame
  # (`/signals/:id`), so the request params typically DO NOT include the current
  # list filters (relevance/status/search/etc.). We therefore parse the referer
  # (the Signals page URL) and rebuild the list state consistently.
  #
  # @return [Hash]
  def reload_email_list_data_from_referer
    list_params = list_params_from_referer
    current_relevance = list_params[:relevance].presence || "relevant"

    emails = current_user_emails
      .includes(:interview_application, :email_sender, interview_application: [ :company, :job_role ])
      .order(email_date: :desc)

    emails = filter_emails_for_list(emails, list_params, current_relevance: current_relevance)

    show_unified_list = current_relevance == "all"

    if show_unified_list
      all_by_thread = group_emails_by_thread(emails)
      pagy_all, all_emails = pagy_array(
        all_by_thread,
        limit: 20,
        page: list_params[:page].presence,
        page_param: :page
      )
      {
        show_unified_list: true,
        grouped_emails: {},
        unmatched_emails: [],
        pagy_unmatched: nil,
        all_emails: all_emails,
        pagy_all: pagy_all
      }
    else
      grouped_emails = group_emails_by_application(emails)
      unmatched_by_thread = group_emails_by_thread(emails.unmatched)
      pagy_unmatched, unmatched_emails = pagy_array(
        unmatched_by_thread,
        limit: 15,
        page: list_params[:unmatched_page].presence,
        page_param: :unmatched_page
      )
      {
        show_unified_list: false,
        grouped_emails: grouped_emails,
        unmatched_emails: unmatched_emails,
        pagy_unmatched: pagy_unmatched,
        all_emails: [],
        pagy_all: nil
      }
    end
  end

  # Returns HTML for the email stats footer
  #
  # @return [String]
  def email_stats_html
    needs_review = Current.user.synced_emails.needs_review.count
    matched = Current.user.synced_emails.matched.count
    "<span>#{needs_review} signals need attention</span><span>#{matched} matched</span>"
  end

  # Extracts list params from the referer URL (best-effort).
  #
  # @return [ActionController::Parameters]
  def list_params_from_referer
    return ActionController::Parameters.new({}) if request.referer.blank?

    uri = URI.parse(request.referer)
    parsed = Rack::Utils.parse_nested_query(uri.query.to_s)
    ActionController::Parameters.new(parsed)
  rescue URI::InvalidURIError
    ActionController::Parameters.new({})
  end

  # Applies the same filters used by `index`, but based on explicit params.
  #
  # @param emails [ActiveRecord::Relation]
  # @param list_params [ActionController::Parameters]
  # @param current_relevance [String]
  # @return [ActiveRecord::Relation]
  def filter_emails_for_list(emails, list_params, current_relevance:)
    filtered = case current_relevance
    when "all"
      emails.visible
    when "interviews"
      emails.interview_related.visible
    when "opportunities"
      emails.potential_opportunities.visible
    else
      emails.relevant
    end

    if list_params[:type].present?
      filtered = filtered.by_type(list_params[:type])
    end

    case list_params[:status]
    when "matched"
      filtered = filtered.matched
    when "unmatched"
      filtered = filtered.unmatched
    when "pending"
      filtered = filtered.pending
    when "ignored"
      filtered = filtered.ignored
    end

    if list_params[:company_id].present?
      company = Company.find_by(id: list_params[:company_id])
      if company
        application_ids = Current.user.interview_applications
          .where(company: company)
          .pluck(:id)
        filtered = filtered.where(interview_application_id: application_ids)
      end
    end

    if list_params[:q].present?
      query = "%#{list_params[:q]}%"
      filtered = filtered.where(
        "subject ILIKE :q OR from_email ILIKE :q OR from_name ILIKE :q OR snippet ILIKE :q",
        q: query
      )
    end

    filtered
  end
end
