# frozen_string_literal: true

module Dedup
  # Service for finding possible duplicate skill tags.
  #
  # Heuristics (deterministic):
  # - Same normalized name (case-insensitive, ignoring non-alphanumeric chars)
  # - Same normalized name + same category_id (stronger signal)
  class FindSkillTagDuplicatesService
    # @param skill_tag [SkillTag]
    # @param limit [Integer]
    def initialize(skill_tag:, limit: 10)
      @skill_tag = skill_tag
      @limit = limit
    end

    # @return [Array<Hash>] [{ record: SkillTag, reasons: Array<String> }]
    def run
      return [] if @skill_tag.nil?

      reasons_by_id = Hash.new { |h, k| h[k] = [] }

      add_name_matches!(reasons_by_id)
      add_name_and_category_matches!(reasons_by_id)

      reasons_by_id.map do |id, reasons|
        { record: SkillTag.find(id), reasons: reasons.uniq }
      end.sort_by { |h| -h[:reasons].size }.first(@limit)
    end

    private

    def add_name_matches!(reasons_by_id)
      key = normalize_alnum(@skill_tag.name)
      return if key.blank?

      SkillTag
        .where.not(id: @skill_tag.id)
        .where("LOWER(REGEXP_REPLACE(name, '[^a-z0-9]', '', 'g')) = ?", key)
        .limit(@limit)
        .pluck(:id)
        .each { |id| reasons_by_id[id] << "Same normalized name" }
    end

    def add_name_and_category_matches!(reasons_by_id)
      return if @skill_tag.category_id.blank?

      key = normalize_alnum(@skill_tag.name)
      return if key.blank?

      SkillTag
        .where.not(id: @skill_tag.id)
        .where(category_id: @skill_tag.category_id)
        .where("LOWER(REGEXP_REPLACE(name, '[^a-z0-9]', '', 'g')) = ?", key)
        .limit(@limit)
        .pluck(:id)
        .each { |id| reasons_by_id[id] << "Same name within same category" }
    end

    def normalize_alnum(text)
      text.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end
  end
end
