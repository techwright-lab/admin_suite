# frozen_string_literal: true

module Dedup
  # Service for merging duplicate job roles.
  #
  # Moves all associations from a source job role to a target job role, then disables
  # the source job role (default) to preserve history while preventing future use.
  #
  # @example
  #   Dedup::MergeJobRoleService.new(source_job_role: a, target_job_role: b).run
  #
  class MergeJobRoleService
    # @param source_job_role [JobRole]
    # @param target_job_role [JobRole]
    # @param disable_source [Boolean] If true, disable source after merge (default)
    def initialize(source_job_role:, target_job_role:, disable_source: true)
      @source_job_role = source_job_role
      @target_job_role = target_job_role
      @disable_source = disable_source
    end

    # Runs the merge.
    #
    # @return [JobRole] The target job role
    def run
      validate!

      JobRole.transaction do
        move_job_listings!
        move_interview_applications!
        move_user_targets!
        move_resume_targets!
        move_users_current_job_role!

        finalize_source!
      end

      @target_job_role
    end

    private

    def validate!
      raise ArgumentError, "source_job_role is required" if @source_job_role.nil?
      raise ArgumentError, "target_job_role is required" if @target_job_role.nil?
      raise ArgumentError, "source_job_role and target_job_role must differ" if @source_job_role.id == @target_job_role.id
    end

    def move_job_listings!
      JobListing.where(job_role_id: @source_job_role.id).update_all(job_role_id: @target_job_role.id)
    end

    def move_interview_applications!
      InterviewApplication.where(job_role_id: @source_job_role.id).update_all(job_role_id: @target_job_role.id)
    end

    def move_users_current_job_role!
      User.where(current_job_role_id: @source_job_role.id).update_all(current_job_role_id: @target_job_role.id)
    end

    def move_user_targets!
      UserTargetJobRole.where(job_role_id: @source_job_role.id).find_each do |utr|
        if UserTargetJobRole.exists?(user_id: utr.user_id, job_role_id: @target_job_role.id)
          utr.destroy!
        else
          utr.update!(job_role_id: @target_job_role.id)
        end
      end
    end

    def move_resume_targets!
      UserResumeTargetJobRole.where(job_role_id: @source_job_role.id).find_each do |urtr|
        if UserResumeTargetJobRole.exists?(user_resume_id: urtr.user_resume_id, job_role_id: @target_job_role.id)
          urtr.destroy!
        else
          urtr.update!(job_role_id: @target_job_role.id)
        end
      end
    end

    def finalize_source!
      if @disable_source
        @source_job_role.disable! unless @source_job_role.disabled?
      else
        @source_job_role.destroy!
      end
    end
  end
end
