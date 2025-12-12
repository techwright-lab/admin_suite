# frozen_string_literal: true

module Admin
  # Controller for managing email senders in the admin panel
  #
  # Provides listing, filtering, viewing, editing, and bulk company assignment
  # for email senders discovered during Gmail sync.
  class EmailSendersController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 30

    before_action :set_email_sender, only: [ :show, :edit, :update ]

    # GET /admin/email_senders
    #
    # Lists email senders with filtering and pagination
    def index
      @pagy, @email_senders = paginate(filtered_senders)
      @stats = calculate_stats
      @filters = filter_params
      @companies = Company.order(:name).limit(100)
      @domains = EmailSender.distinct.pluck(:domain).compact.sort
    end

    # GET /admin/email_senders/:id
    #
    # Shows email sender details with associated emails
    def show
      @recent_emails = @email_sender.synced_emails.order(email_date: :desc).limit(20)
      @same_domain_senders = EmailSender.where(domain: @email_sender.domain)
                                        .where.not(id: @email_sender.id)
                                        .limit(10)
    end

    # GET /admin/email_senders/:id/edit
    def edit
      @companies = Company.order(:name)
    end

    # PATCH /admin/email_senders/:id
    def update
      if @email_sender.update(email_sender_params)
        redirect_to admin_email_sender_path(@email_sender),
                    notice: "Email sender updated successfully."
      else
        @companies = Company.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    # POST /admin/email_senders/bulk_assign
    #
    # Bulk assigns a company to all senders from a specific domain
    def bulk_assign
      domain = params[:domain]
      company_id = params[:company_id]

      if domain.blank? || company_id.blank?
        redirect_to admin_email_senders_path, alert: "Domain and company are required."
        return
      end

      company = Company.find_by(id: company_id)
      unless company
        redirect_to admin_email_senders_path, alert: "Company not found."
        return
      end

      count = EmailSender.where(domain: domain).update_all(
        company_id: company.id,
        verified: true,
        updated_at: Time.current
      )

      redirect_to admin_email_senders_path(domain: domain),
                  notice: "Assigned #{count} sender(s) from #{domain} to #{company.name}."
    end

    private

    # Sets the email sender from params
    #
    # @return [void]
    def set_email_sender
      @email_sender = EmailSender.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_email_senders_path, alert: "Email sender not found."
    end

    # Returns filtered senders based on params
    #
    # @return [ActiveRecord::Relation]
    def filtered_senders
      senders = EmailSender.includes(:company, :auto_detected_company)

      # Filter by assignment status
      case params[:status]
      when "unassigned"
        senders = senders.unassigned
      when "assigned"
        senders = senders.assigned
      when "auto_detected"
        senders = senders.auto_detected
      when "verified"
        senders = senders.verified
      end

      # Filter by domain
      senders = senders.where(domain: params[:domain]) if params[:domain].present?

      # Filter by sender type
      senders = senders.where(sender_type: params[:sender_type]) if params[:sender_type].present?

      # Search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        senders = senders.where(
          "email ILIKE :q OR name ILIKE :q OR domain ILIKE :q",
          q: search_term
        )
      end

      # Sort
      case params[:sort]
      when "email_count"
        senders = senders.most_active
      when "last_seen"
        senders = senders.recent
      when "alphabetical"
        senders = senders.alphabetical
      else
        senders = senders.order(created_at: :desc)
      end

      senders
    end

    # Calculates stats for display
    #
    # @return [Hash]
    def calculate_stats
      {
        total: EmailSender.count,
        unassigned: EmailSender.unassigned.count,
        assigned: EmailSender.assigned.count,
        auto_detected: EmailSender.auto_detected.count,
        verified: EmailSender.verified.count,
        ats_systems: EmailSender.where(sender_type: "ats_system").count,
        unique_domains: EmailSender.distinct.count(:domain)
      }
    end

    # Returns the current filter params
    #
    # @return [Hash]
    def filter_params
      params.permit(:status, :domain, :sender_type, :search, :sort, :page)
    end

    # Strong params for email sender
    #
    # @return [ActionController::Parameters]
    def email_sender_params
      params.require(:email_sender).permit(:company_id, :sender_type, :verified, :name)
    end
  end
end
