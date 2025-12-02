# frozen_string_literal: true

# HtmlScrapingLog model for tracking field-level HTML extraction results
#
# Records detailed information about what the Nokogiri scraping step
# was able to extract, which selectors matched, and extraction quality.
#
# @example
#   log = HtmlScrapingLog.create!(
#     scraping_attempt: attempt,
#     url: "https://example.com/job",
#     domain: "example.com",
#     field_results: {
#       title: { success: true, value: "Software Engineer", selector: "h1.job-title" },
#       location: { success: false, selectors_tried: ["[data-location]", ".location"] }
#     }
#   )
class HtmlScrapingLog < ApplicationRecord
  STATUSES = [ :success, :partial, :failed ].freeze

  TRACKED_FIELDS = %w[
    title
    location
    remote_type
    salary_min
    salary_max
    salary_currency
    description
    company_name
    requirements
    responsibilities
    benefits
  ].freeze

  # Associations
  belongs_to :scraping_attempt
  belongs_to :job_listing, optional: true

  # Enums
  enum :status, {
    success: 0,  # All or most fields extracted
    partial: 1,  # Some fields extracted
    failed: 2    # No fields extracted or error
  }, default: :partial

  # Validations
  validates :url, presence: true
  validates :domain, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :successful, -> { where(status: :success) }
  scope :failed, -> { where(status: :failed) }
  scope :recent_period, ->(days = 7) { where("created_at > ?", days.days.ago) }

  # Callbacks
  before_save :calculate_metrics

  # Returns fields that were successfully extracted
  #
  # @return [Array<String>] Field names
  def extracted_fields
    return [] unless field_results.is_a?(Hash)

    field_results.select { |_, v| v.is_a?(Hash) && v["success"] }.keys
  end

  # Returns fields that failed to extract
  #
  # @return [Array<String>] Field names
  def failed_fields
    return [] unless field_results.is_a?(Hash)

    field_results.reject { |_, v| v.is_a?(Hash) && v["success"] }.keys
  end

  # Returns extraction result for a specific field
  #
  # @param [String, Symbol] field_name The field name
  # @return [Hash, nil] Field result or nil
  def field_result(field_name)
    field_results[field_name.to_s]
  end

  # Checks if a field was successfully extracted
  #
  # @param [String, Symbol] field_name The field name
  # @return [Boolean] True if extracted
  def field_extracted?(field_name)
    result = field_result(field_name)
    result.is_a?(Hash) && result["success"]
  end

  # Returns the selector that matched for a field
  #
  # @param [String, Symbol] field_name The field name
  # @return [String, nil] Selector or nil
  def matched_selector(field_name)
    result = field_result(field_name)
    result["selector"] if result.is_a?(Hash)
  end

  # Returns formatted duration
  #
  # @return [String] Formatted duration
  def formatted_duration
    return "N/A" if duration_ms.nil?

    if duration_ms < 1000
      "#{duration_ms}ms"
    else
      "#{(duration_ms / 1000.0).round(2)}s"
    end
  end

  # Returns extraction rate as percentage
  #
  # @return [String] Formatted percentage
  def extraction_rate_display
    return "N/A" if extraction_rate.nil?

    "#{(extraction_rate * 100).round(0)}%"
  end

  # Returns status badge color
  #
  # @return [String] Tailwind color class
  def status_badge_color
    case status&.to_sym
    when :success then "bg-green-100 text-green-800 dark:bg-green-900/20 dark:text-green-400"
    when :partial then "bg-amber-100 text-amber-800 dark:bg-amber-900/20 dark:text-amber-400"
    when :failed then "bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400"
    else "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300"
    end
  end

  # Class method to calculate aggregate metrics for a domain
  #
  # @param [String] domain The domain
  # @param [Integer] days Number of days to look back
  # @return [Hash] Aggregate metrics
  def self.domain_metrics(domain, days: 7)
    logs = by_domain(domain).recent_period(days)
    return {} if logs.count.zero?

    # Calculate per-field success rates
    field_stats = {}
    TRACKED_FIELDS.each do |field|
      total = 0
      success = 0
      logs.find_each do |log|
        result = log.field_result(field)
        next unless result.is_a?(Hash)

        total += 1
        success += 1 if result["success"]
      end
      field_stats[field] = {
        total: total,
        success: success,
        rate: total > 0 ? (success.to_f / total * 100).round(1) : 0
      }
    end

    {
      total_attempts: logs.count,
      avg_extraction_rate: logs.average(:extraction_rate).to_f.round(2),
      avg_duration_ms: logs.average(:duration_ms).to_f.round(0),
      by_status: logs.group(:status).count,
      field_stats: field_stats
    }
  end

  private

  # Calculates summary metrics before save
  def calculate_metrics
    return unless field_results.is_a?(Hash)

    self.fields_attempted = field_results.keys.count
    self.fields_extracted = extracted_fields.count
    self.extraction_rate = fields_attempted > 0 ? fields_extracted.to_f / fields_attempted : 0.0

    # Determine status based on extraction rate
    self.status = if extraction_rate >= 0.7
                    :success
    elsif extraction_rate > 0
                    :partial
    else
                    :failed
                  end
  end
end

