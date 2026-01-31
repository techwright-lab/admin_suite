# frozen_string_literal: true

module JobListings
  # Service for finding or creating a JobListing from a URL.
  #
  # Normalizes the URL (removes common tracking params), and ensures the JobListing
  # has the required associations (company, job_role).
  #
  # This service intentionally does NOT enqueue scraping jobs; scraping is handled
  # by higher-level workflow orchestration (Signals decision execution, opportunity apply, etc.).
  class UpsertFromUrlService
    # @param url [String]
    # @param company [Company]
    # @param job_role [JobRole]
    # @param title [String, nil]
    def initialize(url:, company:, job_role:, title: nil)
      @url = url
      @company = company
      @job_role = job_role
      @title = title
    end

    # @return [Hash] { job_listing: JobListing, created: Boolean, normalized_url: String }
    def call
      raise ArgumentError, "url is required" if url.blank?
      raise ArgumentError, "company is required" if company.blank?
      raise ArgumentError, "job_role is required" if job_role.blank?

      normalized_url = normalize_url(url)
      existing = JobListing.find_by(url: normalized_url)
      return { job_listing: existing, created: false, normalized_url: normalized_url } if existing

      base_url = normalized_url.split("?").first
      if base_url.present? && base_url != normalized_url
        existing_base = JobListing.find_by(url: base_url)
        return { job_listing: existing_base, created: false, normalized_url: base_url } if existing_base
      end

      jl = JobListing.create!(
        url: normalized_url,
        company: company,
        job_role: job_role,
        title: title.presence || job_role.title,
        status: :active,
        source_id: extract_source_id(normalized_url)
      )
      { job_listing: jl, created: true, normalized_url: normalized_url }
    end

    private

    attr_reader :url, :company, :job_role, :title

    def extract_source_id(url)
      match = url.match(%r{/(jobs?|careers?|positions?)/([^/\?]+)})
      match ? match[2] : nil
    end

    def normalize_url(url)
      uri = URI.parse(url.strip)
      return url.strip unless uri.query.present?

      params = URI.decode_www_form(uri.query).reject do |key, _|
        %w[utm_source utm_medium utm_campaign utm_content utm_term ref source].include?(key.downcase)
      end
      uri.query = params.any? ? URI.encode_www_form(params) : nil
      uri.to_s
    rescue URI::InvalidURIError
      url.strip
    end
  end
end
