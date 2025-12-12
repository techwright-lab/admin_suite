# frozen_string_literal: true

module Admin
  # Controller for viewing connected accounts in the admin panel
  #
  # Provides read-only access to OAuth connected accounts for debugging
  class ConnectedAccountsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_connected_account, only: [ :show ]

    # GET /admin/connected_accounts
    #
    # Lists all connected accounts with filtering
    def index
      @pagy, @connected_accounts = paginate(filtered_accounts)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/connected_accounts/:id
    #
    # Shows connected account details
    def show
      @synced_emails = @connected_account.synced_emails.recent.limit(10)
      @sync_stats = {
        total_emails: @connected_account.synced_emails.count,
        last_synced: @connected_account.last_synced_at,
        sync_enabled: @connected_account.sync_enabled?
      }
    end

    private

    # Sets the connected account from params
    #
    # @return [void]
    def set_connected_account
      @connected_account = ConnectedAccount.includes(:user, :synced_emails).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_connected_accounts_path, alert: "Connected account not found."
    end

    # Returns filtered accounts based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_accounts
      accounts = ConnectedAccount.includes(:user)

      # Filter by provider
      if params[:provider].present?
        accounts = accounts.where(provider: params[:provider])
      end

      # Filter by sync_enabled
      if params[:sync_enabled].present?
        accounts = accounts.where(sync_enabled: params[:sync_enabled] == "true")
      end

      # Filter by token status
      if params[:token_status].present?
        case params[:token_status]
        when "expired"
          accounts = accounts.expired
        when "valid"
          accounts = accounts.valid_tokens
        when "expiring_soon"
          accounts = accounts.where("expires_at < ? AND expires_at > ?", 5.minutes.from_now, Time.current)
        end
      end

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        accounts = accounts.joins(:user).where(
          "users.email_address ILIKE :q OR users.name ILIKE :q OR connected_accounts.email ILIKE :q",
          q: search_term
        )
      end

      # Sort
      case params[:sort]
      when "recent"
        accounts = accounts.order(created_at: :desc)
      when "last_synced"
        accounts = accounts.order(last_synced_at: :desc)
      when "user"
        accounts = accounts.joins(:user).order("users.name")
      else
        accounts = accounts.order(created_at: :desc)
      end

      accounts
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      base = ConnectedAccount.all

      {
        total: base.count,
        google: base.google.count,
        sync_enabled: base.sync_enabled.count,
        expired_tokens: base.expired.count,
        valid_tokens: base.valid_tokens.count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:search, :provider, :sync_enabled, :token_status, :sort, :page)
    end
  end
end
