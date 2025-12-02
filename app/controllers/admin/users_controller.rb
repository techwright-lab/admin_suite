# frozen_string_literal: true

module Admin
  # Controller for managing users in the admin panel
  #
  # Provides listing, viewing, and email lookup for users with
  # visibility into connected accounts and sync status.
  class UsersController < BaseController
    PER_PAGE = 30

    before_action :set_user, only: [:show]

    # GET /admin/users
    #
    # Lists users with filtering and search
    def index
      @page = (params[:page] || 1).to_i
      @users = filtered_users.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @total_count = filtered_users.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/users/:id
    #
    # Shows user details with connected accounts and sync info
    def show
      @connected_accounts = @user.connected_accounts.includes(:synced_emails)
      @recent_synced_emails = @user.synced_emails.order(email_date: :desc).limit(10)
      @sync_stats = calculate_user_sync_stats
    end

    private

    # Sets the user from params
    #
    # @return [void]
    def set_user
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_users_path, alert: "User not found."
    end

    # Returns filtered users based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_users
      users = User.includes(:connected_accounts, :preference)

      # Filter by Gmail connection
      case params[:gmail_status]
      when "connected"
        users = users.joins(:connected_accounts).where(connected_accounts: { provider: "google_oauth2" }).distinct
      when "not_connected"
        users = users.left_joins(:connected_accounts)
                     .where(connected_accounts: { id: nil })
                     .or(User.left_joins(:connected_accounts).where.not(connected_accounts: { provider: "google_oauth2" }))
                     .distinct
      when "sync_enabled"
        users = users.joins(:connected_accounts).where(connected_accounts: { provider: "google_oauth2", sync_enabled: true }).distinct
      end

      # Filter by admin status
      case params[:role]
      when "admin"
        users = users.where(is_admin: true)
      when "user"
        users = users.where(is_admin: [false, nil])
      end

      # Search by email
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        users = users.where("email_address ILIKE :q OR name ILIKE :q", q: search_term)
      end

      # Sort
      case params[:sort]
      when "name"
        users = users.order(:name, :email_address)
      when "recent"
        users = users.order(created_at: :desc)
      when "email_count"
        users = users.left_joins(:synced_emails)
                     .group(:id)
                     .order("COUNT(synced_emails.id) DESC")
      else
        users = users.order(created_at: :desc)
      end

      users
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      {
        total: User.count,
        with_gmail: User.joins(:connected_accounts).where(connected_accounts: { provider: "google_oauth2" }).distinct.count,
        sync_enabled: User.joins(:connected_accounts).where(connected_accounts: { provider: "google_oauth2", sync_enabled: true }).distinct.count,
        admins: User.where(is_admin: true).count,
        total_synced_emails: SyncedEmail.count
      }
    end

    # Calculates sync stats for a specific user
    #
    # @return [Hash]
    def calculate_user_sync_stats
      google_account = @user.google_account

      {
        total_emails: @user.synced_emails.count,
        processed: @user.synced_emails.processed.count,
        needs_review: @user.synced_emails.needs_review.count,
        matched_applications: @user.synced_emails.where.not(interview_application_id: nil).count,
        last_sync: google_account&.last_synced_at,
        sync_enabled: google_account&.sync_enabled?,
        token_status: token_status(google_account)
      }
    end

    # Returns the token status for a connected account
    #
    # @param account [ConnectedAccount, nil]
    # @return [String]
    def token_status(account)
      return "Not connected" unless account

      if account.token_expired?
        "Expired"
      elsif account.token_expiring_soon?
        "Expiring soon"
      else
        "Valid"
      end
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:gmail_status, :role, :search, :sort)
    end
  end
end

