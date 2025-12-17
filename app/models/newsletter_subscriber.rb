# frozen_string_literal: true

# NewsletterSubscriber stores email-only newsletter signups.
#
# Mailkick subscriptions are polymorphic, so we use this model as the subscriber record.
class NewsletterSubscriber < ApplicationRecord
  has_many :mailkick_subscriptions, as: :subscriber, class_name: "Mailkick::Subscription", dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
