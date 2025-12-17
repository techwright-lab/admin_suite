# frozen_string_literal: true

module Resumes
  # Service for orchestrating the complete resume analysis pipeline
  #
  # Pipeline steps:
  # 1. Extract text from uploaded file (PDF/DOCX/DOC/TXT)
  # 2. Send text to AI for skill extraction
  # 3. Create ResumeSkill records from extracted skills
  # 4. Trigger UserSkill aggregation
  #
  # @example
  #   service = Resumes::AnalysisService.new(user_resume)
  #   result = service.run
  #   if result[:success]
  #     puts "Extracted #{result[:skills_count]} skills"
  #   end
  #
  class AnalysisService
    attr_reader :user_resume

    # Initialize the service
    #
    # @param user_resume [UserResume] The resume to analyze
    def initialize(user_resume)
      @user_resume = user_resume
    end

    # Runs the complete analysis pipeline
    #
    # @return [Hash] Result with :success, :skills_count, :error keys
    def run
      user_resume.start_analysis!

      # Step 1: Extract text from file
      text_result = extract_text
      return failure_result(text_result[:error]) unless text_result[:success]

      # Step 2: Extract skills using AI
      skill_result = extract_skills
      return failure_result(skill_result[:error]) unless skill_result[:success]

      # Step 3: Create resume skill records
      skills_created = create_resume_skills(skill_result[:skills])

      # Step 4: Create companies and job roles from work history
      create_entities_from_work_history(skill_result[:work_history])

      # Step 5: Save resume date if extracted
      save_resume_date(skill_result)

      # Step 6: Aggregate user skills
      aggregate_user_skills

      # Persist resume-derived strengths/domains for later display.
      persist_strengths_and_domains(skill_result)

      # Mark analysis as complete
      user_resume.complete_analysis!(summary: skill_result[:summary])

      success_result(skills_created, skill_result)
    rescue StandardError => e
      Rails.logger.error("Resume analysis failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
      user_resume.fail_analysis!(error_message: e.message)
      failure_result(e.message)
    end

    private

    # Step 1: Extract text from the uploaded file
    #
    # @return [Hash] Extraction result
    def extract_text
      TextExtractorService.new(user_resume).extract
    end

    # Step 2: Extract skills using AI
    #
    # @return [Hash] AI extraction result
    def extract_skills
      AiSkillExtractorService.new(user_resume).extract
    end

    # Step 3: Create ResumeSkill records from extracted skills
    #
    # @param skills [Array<Hash>] Extracted skill data
    # @return [Integer] Number of skills created
    def create_resume_skills(skills)
      return 0 if skills.blank?

      created_count = 0

      skills.each do |skill_data|
        skill_tag = find_or_create_skill_tag(skill_data[:name])
        next unless skill_tag

        resume_skill = user_resume.resume_skills.find_or_initialize_by(skill_tag: skill_tag)
        resume_skill.assign_attributes(
          model_level: skill_data[:proficiency],
          confidence_score: skill_data[:confidence],
          category: skill_data[:category],
          evidence_snippet: skill_data[:evidence],
          years_of_experience: skill_data[:years]
        )

        if resume_skill.save
          created_count += 1
        else
          Rails.logger.warn("Failed to create resume skill: #{resume_skill.errors.full_messages.join(", ")}")
        end
      end

      created_count
    end

    # Finds or creates a skill tag with normalization
    #
    # @param name [String] Skill name
    # @return [SkillTag, nil] The skill tag or nil if invalid
    def find_or_create_skill_tag(name)
      return nil if name.blank?

      SkillTag.find_or_create_by_name(name)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Failed to create skill tag '#{name}': #{e.message}")
      nil
    end

    # Creates companies and job roles from extracted work history
    #
    # @param work_history [Array<Hash>] Work history entries
    # @return [void]
    def create_entities_from_work_history(work_history)
      return if work_history.blank?

      work_history.each do |entry|
        # Create company if present
        if entry[:company].present?
          normalized_company = normalize_company_name(entry[:company])
          Company.find_or_create_by(name: normalized_company) if normalized_company.present?
        end

        # Create job role if present
        if entry[:role].present?
          normalized_role = normalize_job_title(entry[:role])
          JobRole.find_or_create_by(title: normalized_role) if normalized_role.present?
        end
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to create entities from work history: #{e.message}")
    end

    # Normalizes company name
    #
    # @param name [String] Raw company name
    # @return [String, nil] Normalized name or nil if invalid
    def normalize_company_name(name)
      return nil if name.blank?

      # Remove common suffixes and clean up
      normalized = name.strip
        .gsub(/\s+(Inc\.?|LLC|Ltd\.?|Corp\.?|Corporation|Company|Co\.?)$/i, "")
        .strip

      # Skip if too short or looks like garbage
      return nil if normalized.length < 2
      return nil if normalized =~ /^[^a-zA-Z]*$/

      normalized
    end

    # Normalizes job title
    #
    # @param title [String] Raw job title
    # @return [String, nil] Normalized title or nil if invalid
    def normalize_job_title(title)
      return nil if title.blank?

      normalized = title.strip

      # Skip if too short or looks like garbage
      return nil if normalized.length < 2
      return nil if normalized =~ /^[^a-zA-Z]*$/

      normalized
    end

    # Saves resume date if extracted by AI
    #
    # @param skill_result [Hash] AI extraction result
    # @return [void]
    def save_resume_date(skill_result)
      return unless skill_result[:resume_date].present?

      user_resume.update!(
        resume_updated_at: skill_result[:resume_date],
        resume_date_confidence: skill_result[:resume_date_confidence],
        resume_date_source: skill_result[:resume_date_source]
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to save resume date: #{e.message}")
    end

    # Aggregates skills for the user
    def aggregate_user_skills
      aggregation_service = SkillAggregationService.new(user_resume.user)

      # Aggregate only skills from this resume
      user_resume.skill_tags.each do |skill_tag|
        aggregation_service.aggregate_skill(skill_tag)
      end
    end

    # Persists resume-derived strengths and domains returned by the extractor.
    #
    # @param skill_result [Hash]
    # @return [void]
    def persist_strengths_and_domains(skill_result)
      strengths = Array(skill_result[:strengths])
        .map { |s| s.to_s.strip }
        .reject(&:blank?)
        .uniq

      domains = Array(skill_result[:domains])
        .map { |d| d.to_s.strip }
        .reject(&:blank?)
        .uniq

      user_resume.update!(strengths: strengths, domains: domains)
    rescue StandardError => e
      Rails.logger.warn("Failed to persist strengths/domains: #{e.message}")
    end

    # Builds success result
    #
    # @param skills_count [Integer] Number of skills created
    # @param skill_result [Hash] AI extraction result
    # @return [Hash]
    def success_result(skills_count, skill_result)
      {
        success: true,
        skills_count: skills_count,
        summary: skill_result[:summary],
        strengths: skill_result[:strengths],
        domains: skill_result[:domains],
        provider: skill_result[:provider],
        model: skill_result[:model]
      }
    end

    # Builds failure result
    #
    # @param error [String] Error message
    # @return [Hash]
    def failure_result(error)
      {
        success: false,
        error: error,
        skills_count: 0
      }
    end
  end
end
