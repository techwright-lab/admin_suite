# frozen_string_literal: true

module Scraping
  module Orchestration
    module Support
      module JobListingUpdater
        module_function

        def update_preliminary!(context, preliminary_data)
          job_listing = context.job_listing
          updates = {}

          updates[:title] = preliminary_data[:title] if preliminary_data[:title].present? && job_listing.title.blank?
          updates[:location] = preliminary_data[:location] if preliminary_data[:location].present? && job_listing.location.blank?
          updates[:remote_type] = preliminary_data[:remote_type] if preliminary_data[:remote_type].present? && job_listing.remote_type == "on_site"
          updates[:salary_min] = preliminary_data[:salary_min] if preliminary_data[:salary_min].present? && job_listing.salary_min.blank?
          updates[:salary_max] = preliminary_data[:salary_max] if preliminary_data[:salary_max].present? && job_listing.salary_max.blank?
          updates[:salary_currency] = preliminary_data[:salary_currency] if preliminary_data[:salary_currency].present?
          updates[:description] = preliminary_data[:description] if preliminary_data[:description].present? && job_listing.description.blank?
          updates[:about_company] = preliminary_data[:about_company] if preliminary_data[:about_company].present? && job_listing.about_company.blank?
          updates[:company_culture] = preliminary_data[:company_culture] if preliminary_data[:company_culture].present? && job_listing.company_culture.blank?

          if preliminary_data[:company_name].present?
            company = EntityResolver.find_or_create_company(context, preliminary_data[:company_name])
            updates[:company] = company if job_listing.company_id.nil? || company.id != job_listing.company_id
          end

          job_role_title = preliminary_data[:job_role_title] || preliminary_data[:title]
          if job_role_title.present?
            department_name = preliminary_data[:job_role_department]
            job_role = EntityResolver.find_or_create_job_role(context, job_role_title, department_name: department_name)
            updates[:job_role] = job_role if job_listing.job_role_id.nil? || job_role.id != job_listing.job_role_id
          end

          return false if updates.empty?

          job_listing.update(updates)
        end

        # Placeholder values that should always be replaced with real extracted data
        PLACEHOLDER_COMPANY_NAMES = [ "Unknown Company", "Unknown" ].freeze
        PLACEHOLDER_JOB_ROLES = [ "Unknown Position", "Unknown Role", "Unknown" ].freeze

        def update_final!(context, result)
          job_listing = context.job_listing

          # Merge custom_sections to preserve existing data while adding new fields
          merged_custom_sections = (job_listing.custom_sections || {}).merge(result[:custom_sections] || {})

          updates = {
            title: result[:title] || job_listing.title,
            description: result[:description] || job_listing.description,
            about_company: result[:about_company] || job_listing.about_company,
            company_culture: result[:company_culture] || job_listing.company_culture,
            requirements: result[:requirements] || job_listing.requirements,
            responsibilities: result[:responsibilities] || job_listing.responsibilities,
            salary_min: result[:salary_min] || job_listing.salary_min,
            salary_max: result[:salary_max] || job_listing.salary_max,
            salary_currency: result[:salary_currency] || job_listing.salary_currency,
            equity_info: result[:equity_info] || job_listing.equity_info,
            benefits: result[:benefits] || job_listing.benefits,
            perks: result[:perks] || job_listing.perks,
            location: result[:location] || job_listing.location,
            remote_type: result[:remote_type] || job_listing.remote_type,
            custom_sections: merged_custom_sections,
            scraped_data: build_scraped_metadata(context, result)
          }

          # Update company if we have extracted data and current is nil/placeholder
          company_name = result[:company] || result[:company_name]
          if company_name.present?
            company = EntityResolver.find_or_create_company(context, company_name)
            should_update_company = job_listing.company_id.nil? ||
                                    company.id != job_listing.company_id ||
                                    is_placeholder_company?(job_listing.company)
            updates[:company] = company if should_update_company
          end

          # Update job role using title as fallback, replacing placeholders
          job_role_title = result[:job_role] || result[:title]
          if job_role_title.present?
            department_name = result[:job_role_department]
            job_role = EntityResolver.find_or_create_job_role(context, job_role_title, department_name: department_name)
            should_update_role = job_listing.job_role_id.nil? ||
                                 job_role.id != job_listing.job_role_id ||
                                 is_placeholder_job_role?(job_listing.job_role)
            updates[:job_role] = job_role if should_update_role
          end

          job_listing.update(updates)
        end

        def is_placeholder_company?(company)
          return true if company.nil?
          PLACEHOLDER_COMPANY_NAMES.any? { |placeholder| company.name&.downcase&.include?(placeholder.downcase) }
        end

        def is_placeholder_job_role?(job_role)
          return true if job_role.nil?
          PLACEHOLDER_JOB_ROLES.any? { |placeholder| job_role.title&.downcase&.include?(placeholder.downcase) }
        end

        def build_scraped_metadata(context, result)
          {
            status: "completed",
            extraction_method: result[:extraction_method] || "ai",
            provider: result[:provider],
            model: result[:model],
            confidence_score: result[:confidence],
            tokens_used: result[:tokens_used],
            extracted_at: Time.current.iso8601,
            duration_seconds: Time.current - context.started_at
          }
        end
      end
    end
  end
end
