# frozen_string_literal: true

module Public
  # Controller for the contact page
  #
  # Handles the public contact form and inquiries.
  class ContactsController < BaseController
    # GET /contact
    #
    # Renders the contact page form.
    def show
      @support_ticket = SupportTicket.new
    end

    # POST /contact
    #
    # Handles contact form submission and creates a support ticket.
    def create
      # Verify Turnstile token
      unless verify_turnstile_token
        @support_ticket = SupportTicket.new(support_ticket_params)
        @support_ticket.errors.add(:base, "Verification failed. Please try again.")
        render :show, status: :unprocessable_entity
        return
      end

      @support_ticket = SupportTicket.new(support_ticket_params)
      @support_ticket.user = Current.user if authenticated?

      if @support_ticket.save
        redirect_to contact_path, notice: "Thank you for your message. We'll be in touch soon!"
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    # Strong parameters for support ticket
    #
    # @return [ActionController::Parameters]
    def support_ticket_params
      params.expect(support_ticket: [ :name, :email, :subject, :message ])
    end

    # Verifies Turnstile token if configured
    #
    # @return [Boolean]
    def verify_turnstile_token
      # Skip verification in development/test environments
      return true if Rails.env.development? || Rails.env.test?
      # Skip if Turnstile is not fully configured
      return true unless turnstile_configured?

      token = params["cf-turnstile-response"]
      CloudflareTurnstileService.verify(token, request.remote_ip)
    end
  end
end
