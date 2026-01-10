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

      # Step 4: Persist expanded work history (experiences + per-experience skills)
      persist_work_history(skill_result[:work_history])

      # Step 5: Save resume date if extracted
      save_resume_date(skill_result)

      # Step 6: Aggregate user skills
      aggregate_user_skills

      # Step 7: Merge work history across resumes into a user-level profile
      Resumes::WorkHistoryAggregationService.new(user_resume.user).run

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

    # Persists expanded work history into normalized tables.
    #
    # @param work_history [Array<Hash>] Work history entries
    # @return [void]
    def persist_work_history(work_history)
      return if work_history.blank?

      user_resume.resume_work_experiences.destroy_all

      work_history.each do |entry|
        next unless entry.is_a?(Hash)

        company_name = entry[:company].to_s.strip
        role_title = entry[:role].to_s.strip
        company_domain = entry[:company_domain].to_s.strip.presence
        role_department = entry[:role_department].to_s.strip.presence

        normalized_company = normalize_company_name(company_name)
        normalized_role = normalize_job_title(role_title)

        company = normalized_company.present? ? Company.find_or_create_by(name: normalized_company) : nil
        job_role = find_or_create_job_role_with_department(normalized_role, role_department)

        experience = user_resume.resume_work_experiences.create!(
          company: company,
          job_role: job_role,
          company_name: company_name.presence,
          role_title: role_title.presence,
          start_date: entry[:start_date],
          end_date: entry[:end_date],
          current: !!entry[:current],
          duration_text: entry[:duration],
          responsibilities: Array(entry[:responsibilities]),
          highlights: Array(entry[:highlights]),
          metadata: { company_domain: company_domain, role_department: role_department }.compact
        )

        Array(entry[:skills_used]).each do |skill_ref|
          next unless skill_ref.is_a?(Hash)

          name = skill_ref[:name].to_s.strip
          next if name.blank?

          skill_tag = SkillTag.find_or_create_by_name(name)
          experience.resume_work_experience_skills.find_or_create_by!(skill_tag: skill_tag) do |row|
            row.confidence_score = skill_ref[:confidence]
            row.evidence_snippet = skill_ref[:evidence]
          end
        end
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to persist work history: #{e.message}")
    end

    # Finds or creates a job role and assigns department if provided
    #
    # @param title [String] Job role title
    # @param department_name [String, nil] Department name
    # @return [JobRole, nil]
    def find_or_create_job_role_with_department(title, department_name)
      return nil if title.blank?

      job_role = JobRole.find_or_create_by(title: title)

      # Assign department if provided and role doesn't have one
      if department_name.present? && job_role.category_id.nil?
        department = Category.find_by(name: department_name, kind: :job_role)
        job_role.update(category: department) if department
      elsif job_role.category_id.nil?
        # Try to infer department from title
        department = infer_department_from_title(title)
        job_role.update(category: department) if department
      end

      job_role
    end

    # Infers department from job role title using keyword matching
    #
    # @param title [String] Job role title
    # @return [Category, nil]
    def infer_department_from_title(title)
      return nil if title.blank?

      title_lower = title.downcase

      department_keywords = {
        "Engineering" => %w[engineer developer software backend frontend fullstack architect sre devops platform],
        "Product" => %w[product owner manager pm],
        "Design" => %w[designer ux ui visual graphic],
        "Data Science" => %w[data scientist analyst analytics machine learning ml ai],
        "DevOps/SRE" => %w[devops sre infrastructure reliability platform],
        "Sales" => %w[sales account executive ae sdr bdr],
        "Marketing" => %w[marketing growth seo sem content brand],
        "Customer Success" => %w[customer success support cx],
        "Finance" => %w[finance accounting financial controller cfo],
        "HR/People" => %w[hr human resources people talent recruiter recruiting],
        "Legal" => %w[legal counsel attorney compliance],
        "Operations" => %w[operations ops logistics supply],
        "Executive" => %w[ceo cto coo cfo cmo chief director vp president],
        "Research" => %w[research scientist r&d],
        "QA/Testing" => %w[qa quality assurance test tester sdet],
        "Security" => %w[security infosec appsec cyber],
        "IT" => %w[it helpdesk administrator admin sysadmin],
        "Content" => %w[content writer editor copywriter]
      }

      department_keywords.each do |dept_name, keywords|
        if keywords.any? { |kw| title_lower.include?(kw) }
          return Category.find_by(name: dept_name, kind: :job_role)
        end
      end

      nil
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

      # De-dupe near-duplicates within the same resume analysis (conservative threshold).
      strengths = Labels::DedupeService.new(strengths, similarity_threshold: 0.9, overlap_threshold: 0.85).run

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
