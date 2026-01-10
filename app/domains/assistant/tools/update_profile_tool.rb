# frozen_string_literal: true

module Assistant
  module Tools
    # Write: update user profile attributes.
    #
    # Updateable attributes:
    # - years_of_experience (integer)
    # - current_company_name (string, finds or creates Company)
    # - current_job_role_title (string, finds or creates JobRole)
    # - linkedin_url, github_url, twitter_url, portfolio_url, gitlab_url (strings)
    # - bio (text)
    #
    # NOTE: Does not allow updating email or password for security.
    class UpdateProfileTool < BaseTool
      ALLOWED_ATTRIBUTES = %w[
        years_of_experience
        current_company_name
        current_job_role_title
        linkedin_url
        github_url
        twitter_url
        portfolio_url
        gitlab_url
        bio
      ].freeze

      def call(args:, tool_execution:)
        updates = extract_updates(args)

        if updates.empty?
          return { success: false, error: "No valid attributes provided to update" }
        end

        changes = apply_updates(updates)

        {
          success: true,
          data: {
            updated_attributes: changes.keys,
            profile: build_profile_summary
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        { success: false, error: e.record.errors.full_messages.join(", ") }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def extract_updates(args)
        updates = {}

        ALLOWED_ATTRIBUTES.each do |attr|
          value = args[attr] || args[attr.to_sym]
          updates[attr] = value if value.present? || value == "" # Allow clearing with empty string
        end

        updates
      end

      def apply_updates(updates)
        changes = {}

        # Handle company - find or create
        if updates.key?("current_company_name")
          company_name = updates["current_company_name"].to_s.strip
          if company_name.blank?
            user.current_company = nil
            changes[:current_company] = nil
          else
            company = Company.where("lower(name) = ?", company_name.downcase).first ||
                      Company.create!(name: company_name)
            user.current_company = company
            changes[:current_company] = company.name
          end
        end

        # Handle job role - find or create
        if updates.key?("current_job_role_title")
          role_title = updates["current_job_role_title"].to_s.strip
          if role_title.blank?
            user.current_job_role = nil
            changes[:current_job_role] = nil
          else
            job_role = JobRole.where("lower(title) = ?", role_title.downcase).first ||
                       JobRole.create!(title: role_title)
            user.current_job_role = job_role
            changes[:current_job_role] = job_role.title
          end
        end

        # Handle years of experience
        if updates.key?("years_of_experience")
          value = updates["years_of_experience"]
          user.years_of_experience = value.present? ? value.to_i.clamp(0, 60) : nil
          changes[:years_of_experience] = user.years_of_experience
        end

        # Handle social URLs
        %w[linkedin_url github_url twitter_url portfolio_url gitlab_url].each do |attr|
          if updates.key?(attr)
            value = updates[attr].to_s.strip
            user.send("#{attr}=", value.presence)
            changes[attr.to_sym] = value.presence
          end
        end

        # Handle bio
        if updates.key?("bio")
          value = updates["bio"].to_s.strip
          user.bio = value.presence
          changes[:bio] = value.present? ? "updated" : "cleared"
        end

        user.save!
        changes
      end

      def build_profile_summary
        {
          name: user.name,
          years_of_experience: user.years_of_experience,
          current_company: user.current_company&.name,
          current_job_role: user.current_job_role&.title,
          bio: user.bio.present? ? user.bio.truncate(100) : nil,
          social_profiles: {
            linkedin: user.linkedin_url.presence,
            github: user.github_url.presence,
            twitter: user.twitter_url.presence,
            portfolio: user.portfolio_url.presence,
            gitlab: user.gitlab_url.presence
          }.compact
        }.compact
      end
    end
  end
end
