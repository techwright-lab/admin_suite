# frozen_string_literal: true

# JobListing model representing job postings
class JobListing < ApplicationRecord
  include Disableable

  REMOTE_TYPES = [ :on_site, :hybrid, :remote ].freeze
  STATUSES = [ :draft, :active, :closed ].freeze
  EXTRACTION_QUALITIES = [ :full, :partial, :limited, :manual ].freeze
  LIMITED_JOB_BOARDS = %w[linkedin indeed glassdoor].freeze

  belongs_to :company
  belongs_to :job_role
  has_many :interview_applications, dependent: :nullify
  has_many :scraping_attempts, dependent: :destroy
  has_many :scraped_job_listing_data, class_name: "ScrapedJobListingData", dependent: :destroy
  has_many :llm_api_logs, class_name: "Ai::LlmApiLog", as: :loggable, dependent: :destroy

  enum :remote_type, REMOTE_TYPES, default: :on_site
  enum :status, STATUSES, default: :active

  attribute :custom_sections, default: -> { {} }
  attribute :scraped_data, default: -> { {} }

  validates :company, presence: true
  validates :job_role, presence: true
  validates :remote_type, inclusion: { in: REMOTE_TYPES.map(&:to_s) }
  validates :status, inclusion: { in: STATUSES.map(&:to_s) }
  validate :url_has_safe_scheme, if: -> { url.present? }

  scope :active, -> { where(status: :active) }
  scope :closed, -> { where(status: :closed) }
  scope :remote, -> { where(remote_type: :remote) }
  scope :recent, -> { order(created_at: :desc) }

  # Returns a display title for the job listing
  # @return [String] Job listing title
  def display_title
    title.presence || job_role.title
  end

  # Returns salary range as a formatted string
  # @return [String, nil] Formatted salary range
  def salary_range
    return nil if salary_min.nil? && salary_max.nil?

    currency_symbol = salary_currency == "USD" ? "$" : salary_currency
    min_formatted = salary_min ? number_with_delimiter(salary_min.to_i) : nil
    max_formatted = salary_max ? number_with_delimiter(salary_max.to_i) : nil

    if min_formatted && max_formatted
      "#{currency_symbol}#{min_formatted} - #{currency_symbol}#{max_formatted} #{salary_currency}"
    elsif min_formatted
      "#{currency_symbol}#{min_formatted}+ #{salary_currency}"
    elsif max_formatted
      "Up to #{currency_symbol}#{max_formatted} #{salary_currency}"
    end
  end

  # Checks if job listing has custom sections
  # @return [Boolean] True if custom sections exist
  def has_custom_sections?
    custom_sections.present? && custom_sections.any?
  end

  # Checks if job listing was scraped
  # @return [Boolean] True if scraped data exists
  def scraped?
    scraped_data.present? && scraped_data.any?
  end

  # Returns formatted remote type
  # @return [String] Formatted remote type
  def remote_type_display
    remote_type.to_s.titleize.gsub("_", "-")
  end

  # Returns location with remote type
  # @return [String] Formatted location display
  def location_display
    if location.present?
      "#{location} (#{remote_type_display})"
    else
      remote_type_display
    end
  end

  # Returns the latest scraping attempt
  # @return [ScrapingAttempt, nil] Latest attempt or nil
  def latest_scraping_attempt
    scraping_attempts.order(created_at: :desc).first
  end

  # Returns extraction status from scraped_data
  # @return [String] Extraction status
  def extraction_status
    scraped_data["status"] || "pending"
  end

  # Returns extraction confidence score
  # @return [Float] Confidence score between 0 and 1
  def extraction_confidence
    scraped_data["confidence_score"] || 0.0
  end

  # Checks if extraction was successful
  # @return [Boolean] True if extraction completed successfully
  def extraction_completed?
    extraction_status == "completed"
  end

  # Checks if extraction needs admin review
  # @return [Boolean] True if needs review
  def extraction_needs_review?
    latest_attempt = latest_scraping_attempt
    return false unless latest_attempt

    latest_attempt.needs_review? || extraction_confidence < 0.7
  end

  # Returns the job board type from scraped_data
  # @return [String, nil] Job board type (linkedin, greenhouse, etc.)
  def job_board
    scraped_data["job_board"] || job_board_id
  end

  # Returns extraction quality from scraped_data
  # @return [String] Extraction quality (full, partial, limited, manual)
  def extraction_quality
    scraped_data["extraction_quality"] || "full"
  end

  # Checks if this job listing has limited extraction data
  # (from sources like LinkedIn that require auth)
  # @return [Boolean] True if extraction was limited
  def limited_extraction?
    extraction_quality == "limited" || LIMITED_JOB_BOARDS.include?(job_board.to_s)
  end

  # Checks if this job listing needs more details from the user
  # @return [Boolean] True if more details would be helpful
  def needs_more_details?
    return true if limited_extraction?
    return true if description.blank? && responsibilities.blank?
    return true if extraction_confidence < 0.5

    false
  end

  # Returns a human-readable explanation of why extraction was limited
  # @return [String, nil] Explanation or nil if not limited
  def limited_extraction_reason
    return nil unless limited_extraction?

    case job_board.to_s
    when "linkedin"
      "LinkedIn requires authentication to access full job details. " \
      "We extracted what was publicly available."
    when "indeed"
      "Indeed limits public access to job details. " \
      "Some information may be incomplete."
    when "glassdoor"
      "Glassdoor requires authentication for full job details. " \
      "We extracted what was publicly available."
    else
      "This job listing has limited data due to source restrictions."
    end
  end

  # Returns a safe URL for linking, or nil if URL is potentially dangerous
  # Only allows http/https schemes to prevent javascript: XSS attacks
  #
  # @return [String, nil] Safe URL or nil
  def safe_url
    return nil if url.blank?

    uri = URI.parse(url.strip)
    %w[http https].include?(uri.scheme&.downcase) ? url : nil
  rescue URI::InvalidURIError
    nil
  end

  private

  # Validates that the URL uses a safe scheme (http/https only)
  # Prevents javascript:, data:, and other dangerous URL schemes
  #
  # @return [void]
  def url_has_safe_scheme
    return if url.blank?

    begin
      uri = URI.parse(url.strip)
      unless %w[http https].include?(uri.scheme&.downcase)
        errors.add(:url, "must use http or https")
      end
    rescue URI::InvalidURIError
      errors.add(:url, "is not a valid URL")
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end
end
