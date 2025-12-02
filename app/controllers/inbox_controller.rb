# frozen_string_literal: true

# Controller for the intelligent inbox view
# Displays synced emails grouped by application with smart filtering
# Supports split-pane layout with Turbo Frames
class InboxController < ApplicationController
  before_action :set_synced_email, only: [ :show, :match_application, :ignore ]

  # GET /inbox
  #
  # Main inbox view with split-pane layout
  def index
    @emails = current_user_emails
      .includes(:interview_application, :email_sender, interview_application: [ :company, :job_role ])
      .order(email_date: :desc)

    # Apply filters
    @emails = filter_by_type(@emails)
    @emails = filter_by_status(@emails)
    @emails = filter_by_company(@emails)
    @emails = search_emails(@emails)

    # Group emails by thread for display (showing latest in each thread)
    @grouped_emails = group_emails_by_application(@emails)
    @unmatched_emails = @emails.unmatched

    # Load filter options
    @email_types = SyncedEmail::EMAIL_TYPES
    @companies = Company.joins(:interview_applications)
      .where(interview_applications: { user_id: Current.user.id })
      .distinct
      .alphabetical

    # If email_id param, pre-select that email
    @selected_email = current_user_emails.find_by(id: params[:email_id]) if params[:email_id]
  end

  # GET /inbox/:id
  #
  # Show email detail - responds to Turbo Frame for split-pane
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
          partial: "inbox/detail_panel",
          locals: { email: @email, thread_emails: @thread_emails, application: @application }
        )
      end
    end
  end

  # PATCH /inbox/:id/match_application
  #
  # Match email to an interview application
  def match_application
    application = Current.user.interview_applications.find_by(id: params[:application_id])

    if application && @email.match_to_application!(application)
      # Also match other emails in the same thread
      match_thread_emails(application) if @email.thread_id.present?

      respond_to do |format|
        format.html { redirect_to inbox_index_path, notice: "Email matched to #{application.company.name}." }
        format.turbo_stream do
          @thread_emails = @email.thread_emails.includes(:email_sender)
          reload_email_list_data
          render turbo_stream: [
            turbo_stream.update("email_detail",
              partial: "inbox/detail_panel",
              locals: { email: @email, thread_emails: @thread_emails, application: application }
            ),
            turbo_stream.update("email_list",
              partial: "inbox/email_list",
              locals: { grouped_emails: @grouped_emails, unmatched_emails: @unmatched_emails, selected_email_id: @email.id }
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
        format.html { redirect_to inbox_index_path, alert: "Could not match email to application." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "email_detail",
            html: "<div class='p-4 text-red-600'>Could not match email</div>"
          )
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /inbox/:id/ignore
  #
  # Mark email as not interview-related
  def ignore
    if @email.ignore!
      respond_to do |format|
        format.html { redirect_to inbox_index_path, notice: "Email marked as not interview-related." }
        format.turbo_stream do
          reload_email_list_data
          render turbo_stream: [
            turbo_stream.update("email_detail",
              partial: "inbox/empty_state"
            ),
            turbo_stream.update("email_list",
              partial: "inbox/email_list",
              locals: { grouped_emails: @grouped_emails, unmatched_emails: @unmatched_emails, selected_email_id: nil }
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
        format.html { redirect_to inbox_index_path, alert: "Could not ignore email." }
        format.turbo_stream do
          @thread_emails = @email.thread_emails.includes(:email_sender)
          render turbo_stream: turbo_stream.update(
            "email_detail",
            partial: "inbox/detail_panel",
            locals: { email: @email, thread_emails: @thread_emails, application: @email.interview_application }
          )
        end
        format.json { render json: { success: false }, status: :unprocessable_entity }
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
      format.html { redirect_to inbox_index_path, alert: "Email not found." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "email_detail",
          partial: "inbox/empty_state"
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
    @unmatched_emails = emails.unmatched
  end

  # Returns HTML for the email stats footer
  #
  # @return [String]
  def email_stats_html
    needs_review = Current.user.synced_emails.unmatched.count
    matched = Current.user.synced_emails.matched.count
    "<span>#{needs_review} needs review</span><span>#{matched} matched</span>"
  end
end
