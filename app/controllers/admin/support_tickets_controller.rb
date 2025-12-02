# frozen_string_literal: true

module Admin
  # Controller for managing support tickets in the admin panel
  #
  # Provides listing, viewing, and status management for support tickets.
  class SupportTicketsController < BaseController
    PER_PAGE = 30

    before_action :set_support_ticket, only: [:show, :update]

    # GET /admin/support_tickets
    #
    # Lists support tickets with filtering and search
    def index
      @page = (params[:page] || 1).to_i
      @support_tickets = filtered_tickets.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @total_count = filtered_tickets.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/support_tickets/:id
    #
    # Shows support ticket details
    def show
    end

    # PATCH /admin/support_tickets/:id
    #
    # Updates support ticket status
    def update
      if @support_ticket.update(support_ticket_params)
        redirect_to admin_support_ticket_path(@support_ticket), notice: "Support ticket updated successfully."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    # Sets the support ticket from params
    #
    # @return [void]
    def set_support_ticket
      @support_ticket = SupportTicket.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_support_tickets_path, alert: "Support ticket not found."
    end

    # Returns filtered tickets based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_tickets
      tickets = SupportTicket.includes(:user)

      # Filter by status
      if params[:status].present?
        tickets = tickets.where(status: params[:status])
      end

      # Search by name, email, or subject
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        tickets = tickets.where(
          "name ILIKE :q OR email ILIKE :q OR subject ILIKE :q OR message ILIKE :q",
          q: search_term
        )
      end

      # Filter by user status
      case params[:user_type]
      when "registered"
        tickets = tickets.where.not(user_id: nil)
      when "guest"
        tickets = tickets.where(user_id: nil)
      end

      # Sort
      case params[:sort]
      when "oldest"
        tickets = tickets.order(created_at: :asc)
      when "name"
        tickets = tickets.order(:name, :created_at)
      when "email"
        tickets = tickets.order(:email, :created_at)
      else
        tickets = tickets.order(created_at: :desc)
      end

      tickets
    end

    # Calculates overall stats
    #
    # @return [Hash]
    def calculate_stats
      {
        total: SupportTicket.count,
        open: SupportTicket.open.count,
        in_progress: SupportTicket.in_progress.count,
        resolved: SupportTicket.resolved.count,
        closed: SupportTicket.closed.count,
        from_users: SupportTicket.where.not(user_id: nil).count,
        from_guests: SupportTicket.where(user_id: nil).count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:status, :search, :user_type, :sort)
    end

    # Strong parameters for support ticket updates
    #
    # @return [ActionController::Parameters]
    def support_ticket_params
      params.expect(support_ticket: [:status])
    end
  end
end

