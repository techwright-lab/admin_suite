# frozen_string_literal: true

module Dedup
  # Service for merging duplicate categories (within the same kind).
  #
  # Repoints all referencing records from a source category to a target category,
  # then disables the source category (default).
  #
  # @example
  #   Dedup::MergeCategoryService.new(source_category: a, target_category: b).run
  #
  class MergeCategoryService
    # @param source_category [Category]
    # @param target_category [Category]
    # @param disable_source [Boolean] If true, disable source after merge (default)
    def initialize(source_category:, target_category:, disable_source: true)
      @source_category = source_category
      @target_category = target_category
      @disable_source = disable_source
    end

    # Runs the merge.
    #
    # @return [Category] The target category
    def run
      validate!

      Category.transaction do
        case @source_category.kind.to_s
        when "job_role"
          JobRole.where(category_id: @source_category.id).update_all(category_id: @target_category.id)
        when "skill_tag"
          SkillTag.where(category_id: @source_category.id).update_all(category_id: @target_category.id)
        else
          raise ArgumentError, "Unsupported category kind: #{@source_category.kind}"
        end

        finalize_source!
      end

      @target_category
    end

    private

    def validate!
      raise ArgumentError, "source_category is required" if @source_category.nil?
      raise ArgumentError, "target_category is required" if @target_category.nil?
      raise ArgumentError, "source_category and target_category must differ" if @source_category.id == @target_category.id
      raise ArgumentError, "categories must have the same kind" if @source_category.kind != @target_category.kind
    end

    def finalize_source!
      if @disable_source
        @source_category.disable! unless @source_category.disabled?
      else
        @source_category.destroy!
      end
    end
  end
end
