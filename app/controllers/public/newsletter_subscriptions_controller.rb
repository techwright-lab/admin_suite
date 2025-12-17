# frozen_string_literal: true

module Public
  # Newsletter capture endpoints (public).
  class NewsletterSubscriptionsController < BaseController
    # POST /newsletter/subscribe
    def create
      email = params[:email].to_s.strip
      if email.blank?
        redirect_back fallback_location: blog_index_path, alert: "Please enter an email."
        return
      end

      subscriber = NewsletterSubscriber.find_or_initialize_by(email: email)
      subscriber.save!

      Mailkick::Subscription.find_or_create_by!(subscriber: subscriber, list: "newsletter")

      redirect_back fallback_location: blog_index_path, notice: "Thanks! You're subscribed."
    rescue ActiveRecord::RecordInvalid
      redirect_back fallback_location: blog_index_path, alert: "Please enter a valid email."
    end

    # GET /newsletter/unsubscribe/:signed_id
    def destroy
      subscriber = NewsletterSubscriber.find_signed!(params[:signed_id])
      Mailkick::Subscription.where(subscriber: subscriber, list: "newsletter").delete_all
      redirect_to blog_index_path, notice: "You have been unsubscribed."
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to blog_index_path, alert: "Invalid unsubscribe link."
    end
  end
end


