# frozen_string_literal: true

# ScrapingAttempt model representing a job listing extraction attempt
class ScrapingAttempt < ApplicationRecord
  include Transitionable

  STATUSES = [
    :pending,      # Initial state, queued
    :fetching,     # Downloading HTML/API data
    :extracting,   # Processing with LLM/parser
    :completed,    # Successfully extracted
    :failed,       # Failed, will retry
    :retrying,     # In retry queue
    :dead_letter,  # Exhausted retries, needs admin
    :manual        # Admin manually fixed
  ].freeze

  EXTRACTION_METHODS = [ :api, :ai ].freeze

  belongs_to :job_listing
  has_one :scraped_job_listing_data, dependent: :nullify
  has_many :llm_api_logs, class_name: "Ai::LlmApiLog", as: :loggable, dependent: :destroy
  has_many :scraping_events, dependent: :destroy
  has_one :html_scraping_log, dependent: :destroy

  # Define enum for status to map integer values to state names
  enum :status, {
    pending: 0,
    fetching: 1,
    extracting: 2,
    completed: 3,
    failed: 4,
    retrying: 5,
    dead_letter: 6,
    manual: 7
  }, default: :pending

  validates :url, presence: true
  validates :domain, presence: true
  validates :extraction_method, inclusion: { in: EXTRACTION_METHODS.map(&:to_s) }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :by_status, ->(status) { where(status: status) }
  scope :needs_review, -> { where(status: [ :dead_letter, :failed ]) }
  scope :recent_period, ->(days = 7) { where("created_at > ?", days.days.ago) }

  # Status state machine
  aasm column: :status, enum: true, with_klass: BaseAasm do
    requires_guards!
    log_transitions!

    state :pending, initial: true
    state :fetching
    state :extracting
    state :completed
    state :failed
    state :retrying
    state :dead_letter
    state :manual

    event :start_fetch do
      transitions from: [ :pending, :retrying ], to: :fetching
    end

    event :start_extract do
      transitions from: :fetching, to: :extracting
    end

    event :mark_completed do
      transitions from: :extracting, to: :completed
    end

    event :mark_failed do
      transitions from: [ :fetching, :extracting, :retrying ], to: :failed
    end

    event :retry_attempt do
      transitions from: :failed, to: :retrying
    end

    event :send_to_dlq do
      transitions from: :failed, to: :dead_letter
    end

    event :mark_manual do
      transitions from: [ :dead_letter, :failed ], to: :manual
    end
  end

  # Returns badge color for status
  # @return [String] Color name for badge
  def status_badge_color
    case status.to_sym
    when :completed then "success"
    when :pending, :fetching, :extracting, :retrying then "info"
    when :failed then "danger"
    when :dead_letter then "warning"
    when :manual then "neutral"
    else "neutral"
    end
  end

  # Checks if this attempt needs admin review
  # @return [Boolean] True if needs review
  def needs_review?
    dead_letter? || (failed? && retry_count >= 3)
  end

  # Checks if HTML fetch step failed
  # @return [Boolean] True if HTML fetch failed
  def html_fetch_failed?
    failed_step == "html_fetch"
  end

  # Checks if API extraction step failed
  # @return [Boolean] True if API extraction failed
  def api_extraction_failed?
    failed_step == "api_extraction"
  end

  # Checks if AI extraction step failed
  # @return [Boolean] True if AI extraction failed
  def ai_extraction_failed?
    failed_step == "ai_extraction"
  end

  # Returns cached HTML data if available
  # @return [ScrapedJobListingData, nil] Cached HTML data or nil
  def cached_html_data
    scraped_job_listing_data || ScrapedJobListingData.find_valid_for_url(url, job_listing: job_listing)
  end

  # Returns formatted duration
  # @return [String, nil] Formatted duration
  def formatted_duration
    return nil if duration_seconds.nil?

    if duration_seconds < 1
      "#{(duration_seconds * 1000).round}ms"
    elsif duration_seconds < 60
      "#{duration_seconds.round(2)}s"
    else
      minutes = (duration_seconds / 60).floor
      seconds = (duration_seconds % 60).round
      "#{minutes}m #{seconds}s"
    end
  end

  # Returns success rate for this domain
  # @return [Float] Success rate as percentage
  def self.success_rate_for_domain(domain, days = 7)
    attempts = by_domain(domain).recent_period(days)
    return 0.0 if attempts.count.zero?

    completed = attempts.where(status: :completed).count
    (completed.to_f / attempts.count * 100).round(1)
  end
end
