# frozen_string_literal: true

module Dedup
  # Service for finding possible duplicate job roles.
  #
  # Heuristics (deterministic):
  # - Same normalized title (case-insensitive, ignoring non-alphanumeric chars)
  # - Same normalized title + same category_id (stronger signal)
  class FindJobRoleDuplicatesService
    # @param job_role [JobRole]
    # @param limit [Integer]
    def initialize(job_role:, limit: 10)
      @job_role = job_role
      @limit = limit
    end

    # @return [Array<Hash>] [{ record: JobRole, reasons: Array<String> }]
    def run
      return [] if @job_role.nil?

      reasons_by_id = Hash.new { |h, k| h[k] = [] }

      add_title_matches!(reasons_by_id)
      add_title_and_category_matches!(reasons_by_id)

      reasons_by_id.map do |id, reasons|
        { record: JobRole.find(id), reasons: reasons.uniq }
      end.sort_by { |h| -h[:reasons].size }.first(@limit)
    end

    private

    def add_title_matches!(reasons_by_id)
      key = normalize_alnum(@job_role.title)
      return if key.blank?

      JobRole
        .where.not(id: @job_role.id)
        .where("LOWER(REGEXP_REPLACE(title, '[^a-z0-9]', '', 'g')) = ?", key)
        .limit(@limit)
        .pluck(:id)
        .each { |id| reasons_by_id[id] << "Same normalized title" }
    end

    def add_title_and_category_matches!(reasons_by_id)
      return if @job_role.category_id.blank?

      key = normalize_alnum(@job_role.title)
      return if key.blank?

      JobRole
        .where.not(id: @job_role.id)
        .where(category_id: @job_role.category_id)
        .where("LOWER(REGEXP_REPLACE(title, '[^a-z0-9]', '', 'g')) = ?", key)
        .limit(@limit)
        .pluck(:id)
        .each { |id| reasons_by_id[id] << "Same title within same category" }
    end

    def normalize_alnum(text)
      text.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end
  end
end
