# frozen_string_literal: true

module Dedup
  # Service for merging duplicate companies.
  #
  # Moves all associations from a source company to a target company, then disables
  # the source company (default) to preserve history while preventing future use.
  #
  # @example
  #   service = Dedup::MergeCompanyService.new(source_company: a, target_company: b)
  #   service.run
  #
  class MergeCompanyService
    # @param source_company [Company]
    # @param target_company [Company]
    # @param disable_source [Boolean] If true, disable source after merge (default)
    def initialize(source_company:, target_company:, disable_source: true)
      @source_company = source_company
      @target_company = target_company
      @disable_source = disable_source
    end

    # Runs the merge.
    #
    # @return [Company] The target company
    # @raise [ArgumentError] If source and target are invalid
    # @raise [ActiveRecord::RecordInvalid] If updates fail
    def run
      validate!

      Company.transaction do
        move_job_listings!
        move_interview_applications!
        move_user_targets!
        move_resume_targets!
        move_users_current_company!
        move_email_senders!

        finalize_source!
      end

      @target_company
    end

    private

    def validate!
      raise ArgumentError, "source_company is required" if @source_company.nil?
      raise ArgumentError, "target_company is required" if @target_company.nil?
      raise ArgumentError, "source_company and target_company must differ" if @source_company.id == @target_company.id
    end

    def move_job_listings!
      JobListing.where(company_id: @source_company.id).update_all(company_id: @target_company.id)
    end

    def move_interview_applications!
      InterviewApplication.where(company_id: @source_company.id).update_all(company_id: @target_company.id)
    end

    def move_users_current_company!
      User.where(current_company_id: @source_company.id).update_all(current_company_id: @target_company.id)
    end

    def move_email_senders!
      EmailSender.where(company_id: @source_company.id).update_all(company_id: @target_company.id)
      EmailSender.where(auto_detected_company_id: @source_company.id).update_all(auto_detected_company_id: @target_company.id)
    end

    def move_user_targets!
      UserTargetCompany.where(company_id: @source_company.id).find_each do |utc|
        if UserTargetCompany.exists?(user_id: utc.user_id, company_id: @target_company.id)
          utc.destroy!
        else
          utc.update!(company_id: @target_company.id)
        end
      end
    end

    def move_resume_targets!
      UserResumeTargetCompany.where(company_id: @source_company.id).find_each do |urtc|
        if UserResumeTargetCompany.exists?(user_resume_id: urtc.user_resume_id, company_id: @target_company.id)
          urtc.destroy!
        else
          urtc.update!(company_id: @target_company.id)
        end
      end
    end

    def finalize_source!
      if @disable_source
        @source_company.disable! unless @source_company.disabled?
      else
        @source_company.destroy!
      end
    end
  end
end
