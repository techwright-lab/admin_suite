# frozen_string_literal: true

module Dedup
  # Service for finding possible duplicate companies.
  #
  # Heuristics (deterministic):
  # - Same normalized name (case-insensitive, ignoring non-alphanumeric chars)
  # - Same website host (when present)
  class FindCompanyDuplicatesService
    require "uri"

    # @param company [Company]
    # @param limit [Integer]
    def initialize(company:, limit: 10)
      @company = company
      @limit = limit
    end

    # @return [Array<Hash>] [{ record: Company, reasons: Array<String> }]
    def run
      return [] if @company.nil?

      reasons_by_id = Hash.new { |h, k| h[k] = [] }

      add_name_matches!(reasons_by_id)
      add_website_host_matches!(reasons_by_id)

      reasons_by_id.map do |id, reasons|
        { record: Company.find(id), reasons: reasons.uniq }
      end.sort_by { |h| -h[:reasons].size }.first(@limit)
    end

    private

    def add_name_matches!(reasons_by_id)
      key = normalize_alnum(@company.name)
      return if key.blank?

      Company
        .where.not(id: @company.id)
        .where("LOWER(REGEXP_REPLACE(name, '[^a-z0-9]', '', 'g')) = ?", key)
        .limit(@limit)
        .pluck(:id)
        .each { |id| reasons_by_id[id] << "Same normalized name" }
    end

    def add_website_host_matches!(reasons_by_id)
      host = extract_host(@company.website)
      return if host.blank?

      Company
        .where.not(id: @company.id)
        .where("website ILIKE ?", "%#{host}%")
        .limit(@limit * 3)
        .find_each do |candidate|
          next unless extract_host(candidate.website) == host
          reasons_by_id[candidate.id] << "Same website host (#{host})"
        end
    end

    def normalize_alnum(text)
      text.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    def extract_host(url)
      return nil if url.blank?

      begin
        uri = URI.parse(url.strip)
        host = uri.host
        host = URI.parse("https://#{url.strip}").host if host.blank?
        host&.downcase
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
