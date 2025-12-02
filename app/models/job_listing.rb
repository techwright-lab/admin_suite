# frozen_string_literal: true

# JobListing model representing job postings
class JobListing < ApplicationRecord
  REMOTE_TYPES = [ :on_site, :hybrid, :remote ].freeze
  STATUSES = [ :draft, :active, :closed ].freeze

  belongs_to :company
  belongs_to :job_role
  has_many :interview_applications, dependent: :nullify
  has_many :scraping_attempts, dependent: :destroy
  has_many :scraped_job_listing_data, class_name: "ScrapedJobListingData", dependent: :destroy
  has_many :ai_extraction_logs, dependent: :destroy

  enum :remote_type, REMOTE_TYPES, default: :on_site
  enum :status, STATUSES, default: :active

  attribute :custom_sections, default: -> { {} }
  attribute :scraped_data, default: -> { {} }

  validates :company, presence: true
  validates :job_role, presence: true
  validates :remote_type, inclusion: { in: REMOTE_TYPES.map(&:to_s) }
  validates :status, inclusion: { in: STATUSES.map(&:to_s) }

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

  private

  def number_with_delimiter(number)
    number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end
end
