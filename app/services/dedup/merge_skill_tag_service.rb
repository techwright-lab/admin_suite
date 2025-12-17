# frozen_string_literal: true

module Dedup
  # Service for merging duplicate skill tags.
  #
  # Moves join associations from a source skill tag to a target skill tag, handling
  # uniqueness constraints, then disables the source tag (default).
  #
  # @example
  #   Dedup::MergeSkillTagService.new(source_skill_tag: a, target_skill_tag: b).run
  #
  class MergeSkillTagService
    # @param source_skill_tag [SkillTag]
    # @param target_skill_tag [SkillTag]
    # @param disable_source [Boolean] If true, disable source after merge (default)
    def initialize(source_skill_tag:, target_skill_tag:, disable_source: true)
      @source_skill_tag = source_skill_tag
      @target_skill_tag = target_skill_tag
      @disable_source = disable_source
    end

    # Runs the merge.
    #
    # @return [SkillTag] The target skill tag
    def run
      validate!

      SkillTag.transaction do
        move_application_skill_tags!
        move_resume_skills!
        move_user_skills!

        finalize_source!
      end

      @target_skill_tag
    end

    private

    def validate!
      raise ArgumentError, "source_skill_tag is required" if @source_skill_tag.nil?
      raise ArgumentError, "target_skill_tag is required" if @target_skill_tag.nil?
      raise ArgumentError, "source_skill_tag and target_skill_tag must differ" if @source_skill_tag.id == @target_skill_tag.id
    end

    def move_application_skill_tags!
      ApplicationSkillTag.where(skill_tag_id: @source_skill_tag.id).find_each do |join|
        if ApplicationSkillTag.exists?(interview_id: join.interview_id, skill_tag_id: @target_skill_tag.id)
          join.destroy!
        else
          join.update!(skill_tag_id: @target_skill_tag.id)
        end
      end
    end

    def move_resume_skills!
      ResumeSkill.where(skill_tag_id: @source_skill_tag.id).find_each do |rs|
        if ResumeSkill.exists?(user_resume_id: rs.user_resume_id, skill_tag_id: @target_skill_tag.id)
          rs.destroy!
        else
          rs.update!(skill_tag_id: @target_skill_tag.id)
        end
      end
    end

    def move_user_skills!
      UserSkill.where(skill_tag_id: @source_skill_tag.id).find_each do |us|
        if UserSkill.exists?(user_id: us.user_id, skill_tag_id: @target_skill_tag.id)
          us.destroy!
        else
          us.update!(skill_tag_id: @target_skill_tag.id)
        end
      end
    end

    def finalize_source!
      if @disable_source
        @source_skill_tag.disable! unless @source_skill_tag.disabled?
      else
        @source_skill_tag.destroy!
      end
    end
  end
end
