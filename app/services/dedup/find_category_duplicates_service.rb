# frozen_string_literal: true

module Dedup
  # Service for finding possible duplicate categories.
  #
  # Heuristics (deterministic):
  # - Same kind + same normalized name (case-insensitive, ignoring non-alphanumeric chars)
  class FindCategoryDuplicatesService
    # @param category [Category]
    # @param limit [Integer]
    def initialize(category:, limit: 10)
      @category = category
      @limit = limit
    end

    # @return [Array<Hash>] [{ record: Category, reasons: Array<String> }]
    def run
      return [] if @category.nil?

      key = normalize_alnum(@category.name)
      return [] if key.blank?

      Category
        .where.not(id: @category.id)
        .where(kind: @category.kind)
        .where("LOWER(REGEXP_REPLACE(name, '[^a-z0-9]', '', 'g')) = ?", key)
        .limit(@limit)
        .map { |c| { record: c, reasons: [ "Same normalized name within kind" ] } }
    end

    private

    def normalize_alnum(text)
      text.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end
  end
end
