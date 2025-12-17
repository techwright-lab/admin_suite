# frozen_string_literal: true

require "digest"

# ScrapedJobListingData model for caching HTML content with validity periods
#
# Stores fetched HTML content to avoid repeated network requests and enable
# idempotent retries of extraction steps.
class ScrapedJobListingData < ApplicationRecord
  VALIDITY_PERIOD_DAYS = 30

  belongs_to :job_listing
  belongs_to :scraping_attempt, optional: true

  validates :url, presence: true
  validates :valid_until, presence: true
  validates :content_hash, uniqueness: { scope: :url }, allow_nil: true

  scope :valid, -> { where("valid_until > ?", Time.current) }
  scope :expired, -> { where("valid_until <= ?", Time.current) }
  scope :for_url, ->(url) { where(url: normalize_url(url)) }

  # Finds or creates a valid cache entry for a URL
  #
  # @param [String] url The job listing URL
  # @param [JobListing] job_listing The job listing
  # @return [ScrapedJobListingData, nil] Cache entry or nil
  def self.find_valid_for_url(url, job_listing: nil)
    normalized_url = normalize_url(url)
    valid.for_url(normalized_url)
         .where(job_listing: job_listing)
         .order(valid_until: :desc)
         .first
  end

  # Creates a new cache entry with HTML content
  #
  # @param [String] url The job listing URL
  # @param [String] html_content The HTML content
  # @param [JobListing] job_listing The job listing
  # @param [ScrapingAttempt] scraping_attempt Optional scraping attempt
  # @param [Hash] metadata Additional fetch metadata
  # @return [ScrapedJobListingData] The created cache entry
  def self.create_with_html(url:, html_content:, job_listing:, scraping_attempt: nil, http_status: nil, metadata: {})
    normalized_url = normalize_url(url)
    content_hash = Digest::SHA256.hexdigest(html_content)
    cleaned_html = clean_html(html_content, url: url)

    create!(
      job_listing: job_listing,
      scraping_attempt: scraping_attempt,
      url: normalized_url,
      html_content: html_content,
      cleaned_html: cleaned_html,
      content_hash: content_hash,
      http_status: http_status,
      valid_until: VALIDITY_PERIOD_DAYS.days.from_now,
      fetch_metadata: metadata
    )
  end

  # Normalizes URL for consistent lookup
  #
  # @param [String] url The URL to normalize
  # @return [String] Normalized URL
  def self.normalize_url(url)
    uri = URI.parse(url)
    # Remove query params and fragments for consistency
    "#{uri.scheme}://#{uri.host}#{uri.path}".downcase
  rescue URI::InvalidURIError
    url.to_s.downcase
  end

  # Cleans HTML content for better extraction
  #
  # Uses board-specific cleaners when URL is known, otherwise falls back to generic.
  #
  # @param [String] html The raw HTML
  # @param [String, nil] url Optional URL to determine board-specific cleaner
  # @return [String] Cleaned HTML text
  def self.clean_html(html, url: nil)
    return "" if html.blank?

    cleaner = if url.present?
                Scraping::HtmlCleaners::CleanerFactory.cleaner_for_url(url)
    else
                Scraping::NokogiriHtmlCleanerService.new
    end
    cleaner.clean(html)
  end

  # Checks if this cache entry is still valid (not expired)
  #
  # @return [Boolean] True if valid
  def cache_valid?
    valid_until > Time.current
  end

  # Checks if this cache entry has expired
  #
  # @return [Boolean] True if expired
  def expired?
    !cache_valid?
  end

  # Marks this cache entry as expired
  #
  # @return [Boolean] True if updated
  def expire!
    update(valid_until: Time.current - 1.second)
  end

  # Returns the HTML content to use (cleaned if available, otherwise raw)
  #
  # @return [String] HTML content
  def html_for_extraction
    cleaned_html.presence || html_content
  end
end
