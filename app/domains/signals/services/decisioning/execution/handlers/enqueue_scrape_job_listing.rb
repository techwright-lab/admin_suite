# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class EnqueueScrapeJobListing < BaseHandler
          def call(step)
            params = step["params"] || {}
            url = params["url"].to_s
            force = !!params["force"]
            return { "action" => "enqueue_scrape_job_listing", "status" => "no_url" } if url.blank?

            job_listing = JobListing.find_by(url: normalize_url(url)) || JobListing.find_by(url: url)
            return { "action" => "enqueue_scrape_job_listing", "status" => "no_job_listing" } unless job_listing

            if !force && job_listing.scraped?
              return { "action" => "enqueue_scrape_job_listing", "status" => "already_scraped", "job_listing_id" => job_listing.id }
            end

            ScrapeJobListingJob.perform_later(job_listing)
            { "action" => "enqueue_scrape_job_listing", "job_listing_id" => job_listing.id }
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
