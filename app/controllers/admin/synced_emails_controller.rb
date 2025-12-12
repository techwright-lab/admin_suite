# frozen_string_literal: true

module Admin
  # Controller for managing synced emails in the admin panel
  #
  # Provides viewing and manual matching of synced emails
  class SyncedEmailsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_synced_email, only: [ :show, :edit, :update ]

    # GET /admin/synced_emails
    #
    # Lists synced emails with filtering
    def index
      @pagy, @synced_emails = paginate(filtered_emails)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/synced_emails/:id
    #
    # Shows email details
    def show
      @interview_applications = @synced_email.user.interview_applications.recent.limit(10) if @synced_email.user.present?
    end

    # GET /admin/synced_emails/:id/edit
    #
    # Edit email for manual matching
    def edit
      @interview_applications = @synced_email.user.interview_applications.recent.limit(20) if @synced_email.user.present?
    end

    # PATCH/PUT /admin/synced_emails/:id
    #
    # Update email (mainly for manual matching)
    def update
      if @synced_email.update(synced_email_params)
        redirect_to admin_synced_email_path(@synced_email), notice: "Email updated successfully."
      else
        @interview_applications = @synced_email.user.interview_applications.recent.limit(20) if @synced_email.user.present?
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Sets the synced email from params
    #
    # @return [void]
    def set_synced_email
      @synced_email = SyncedEmail.includes(:user, :interview_application, :email_sender, :connected_account).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_synced_emails_path, alert: "Synced email not found."
    end

    # Returns filtered emails based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_emails
      emails = SyncedEmail.includes(:user, :interview_application, :email_sender)

      # Filter by status
      if params[:status].present?
        emails = emails.where(status: params[:status])
      end

      # Filter by email_type
      if params[:email_type].present?
        emails = emails.where(email_type: params[:email_type])
      end

      # Filter by matched/unmatched
      if params[:matched].present?
        case params[:matched]
        when "matched"
          emails = emails.where.not(interview_application_id: nil)
        when "unmatched"
          emails = emails.where(interview_application_id: nil)
        end
      end

      # Filter by user
      if params[:user_id].present?
        emails = emails.where(user_id: params[:user_id])
      end

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        emails = emails.where("subject ILIKE :q OR from_email ILIKE :q OR from_name ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "recent"
        emails = emails.order(email_date: :desc)
      when "oldest"
        emails = emails.order(email_date: :asc)
      when "subject"
        emails = emails.order(:subject)
      else
        emails = emails.order(email_date: :desc)
      end

      emails
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = SyncedEmail.all

      {
        total: base.count,
        pending: base.where(status: :pending).count,
        processed: base.where(status: :processed).count,
        needs_review: base.needs_review.count,
        unmatched: base.unmatched.count,
        matched: base.matched.count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :status, :email_type, :matched, :user_id, :sort, :page)
    end

    # Strong params for synced email
    #
    # @return [ActionController::Parameters] Permitted params
    def synced_email_params
      params.require(:synced_email).permit(:interview_application_id, :email_type, :status)
    end
  end
end
