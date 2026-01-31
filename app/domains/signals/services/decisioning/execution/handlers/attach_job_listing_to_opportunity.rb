# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class AttachJobListingToOpportunity < BaseHandler
          def call(step)
            params = step["params"] || {}
            url = params["url"].to_s
            return { "action" => "attach_job_listing_to_opportunity", "status" => "no_url" } if url.blank?

            opportunity = Opportunity.find_by(synced_email_id: synced_email.id)
            return { "action" => "attach_job_listing_to_opportunity", "status" => "no_opportunity" } unless opportunity

            job_listing = JobListing.find_by(url: normalize_url(url)) || JobListing.find_by(url: url)
            return { "action" => "attach_job_listing_to_opportunity", "status" => "no_job_listing" } unless job_listing

            if opportunity.job_listing_id == job_listing.id
              return { "action" => "attach_job_listing_to_opportunity", "status" => "already_attached", "opportunity_id" => opportunity.id, "job_listing_id" => job_listing.id }
            end

            opportunity.update!(job_listing: job_listing)
            { "action" => "attach_job_listing_to_opportunity", "opportunity_id" => opportunity.id, "job_listing_id" => job_listing.id }
          end

          private

          def normalize_url(url)
            uri = URI.parse(url.strip)
            return url.strip unless uri.query.present?

            params = URI.decode_www_form(uri.query).reject do |key, _|
              %w[utm_source utm_medium utm_campaign utm_content utm_term ref source].include?(key.downcase)
            end
            uri.query = params.any? ? URI.encode_www_form(params) : nil
            uri.to_s
          rescue URI::InvalidURIError
            url.strip
          end
        end
      end
    end
  end
end
