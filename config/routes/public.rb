# frozen_string_literal: true

# Public pages routes
#
# Marketing and public-facing pages that don't require authentication
# Includes: Contact, Legal, Blog, Newsletter, Sitemap

scope module: :public do
  # Contact form
  resource :contact, only: [ :show, :create ]

  # Legal pages
  get "privacy", to: "legal#privacy", as: :privacy
  get "terms", to: "legal#terms", as: :terms
  get "cookies", to: "legal#cookies_policy", as: :cookies

  # Blog
  resources :blog, only: [ :index, :show ], param: :slug
  get "blog/tags/:tag", to: "blog_tags#show", as: :blog_tag

  # Newsletter
  post "newsletter/subscribe", to: "newsletter_subscriptions#create", as: :newsletter_subscribe
  get "newsletter/unsubscribe/:signed_id", to: "newsletter_subscriptions#destroy", as: :newsletter_unsubscribe

  # Sitemap
  get "sitemap", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
end
