# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class UpsertJobListingFromUrl < BaseHandler
          def call(step)
            params = step["params"] || {}
            url = params["url"].to_s
            return { "action" => "upsert_job_listing_from_url", "status" => "no_url" } if url.blank?

            company = find_or_create_company(params["company_name"])
            job_role = find_or_create_job_role(params["job_role_title"] || params["job_title"])

            res = JobListings::UpsertFromUrlService.new(
              url: url,
              company: company,
              job_role: job_role,
              title: params["job_title"].presence || job_role.title
            ).call

            {
              "action" => "upsert_job_listing_from_url",
              "status" => (res[:created] ? "created" : "already_exists"),
              "job_listing_id" => res[:job_listing].id
            }
          end

          private

          def find_or_create_company(name)
            normalized = name.to_s.strip
            normalized = "Unknown Company" if normalized.blank?
            existing = Company.find_by("LOWER(name) = ?", normalized.downcase)
            return existing if existing

            Company.create!(name: normalized.titleize)
          end

          def find_or_create_job_role(title)
            t = title.to_s.strip
            t = "Unknown Position" if t.blank?
            existing = JobRole.find_by("LOWER(title) = ?", t.downcase)
            return existing if existing

            JobRole.create!(title: t)
          end
        end
      end
    end
  end
end
