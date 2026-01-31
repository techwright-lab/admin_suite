# frozen_string_literal: true

module Signals
  module Decisioning
    module Rules
      class OpportunityRule < BaseRule
        MIN_CLASSIFICATION_CONFIDENCE = 0.7

        def call
          return nil if matched?

          k = kind
          return nil unless %w[recruiter_outreach potential_opportunity].include?(k)

          classification_conf = input.dig("facts", "classification", "confidence").to_f
          return { decision: "noop", reason: "opportunity_low_confidence" } if classification_conf < MIN_CLASSIFICATION_CONFIDENCE

          evidence = Array(input.dig("facts", "classification", "evidence")).first(3)
          evidence = Array(input.dig("facts", "action_links")).first(1).map { |l| "job posting: #{l["url"]}" } if evidence.empty?
          return { decision: "noop", reason: "opportunity_no_evidence" } if evidence.empty?

          company_name = input.dig("facts", "entities", "company", "name")
          recruiter_name = input.dig("facts", "entities", "recruiter", "name") || input.dig("event", "from", "name")
          recruiter_email = input.dig("facts", "entities", "recruiter", "email") || input.dig("event", "from", "email")
          job_title = input.dig("facts", "entities", "job", "title")
          job_url = choose_job_url

          extracted_links = build_extracted_links(job_url)

          steps = [
            {
              "step_id" => "create_opportunity",
              "action" => "create_opportunity",
              "target" => step_factory.target(selector: "none").merge("application_id" => nil),
              "params" => {
                "company_name" => company_name,
                "job_title" => job_title,
                "job_url" => job_url,
                "recruiter_name" => recruiter_name,
                "recruiter_email" => recruiter_email,
                "extracted_links" => extracted_links,
                "source" => { "synced_email_id" => email_id }
              },
              "preconditions" => [],
              "evidence" => evidence,
              "risk" => "low"
            }
          ]

          if job_url.present?
            steps.concat(job_listing_steps(job_url, company_name, job_title))
          end

          { decision: "apply", confidence: 0.75, reasons: [ "recruiter_outreach_unmatched" ], steps: steps }
        end

        private

        def choose_job_url
          input.dig("facts", "entities", "job", "url") ||
            Array(input.dig("facts", "action_links")).map { |l| l["url"] }.find(&:present?) ||
            Array(input.dig("event", "links")).map { |l| l["url"] }.find(&:present?)
        end

        def build_extracted_links(job_url)
          links = Array(input.dig("event", "links")).map do |l|
            {
              "url" => l["url"].to_s,
              "type" => (l["url"].to_s == job_url.to_s ? "job_posting" : "unknown"),
              "description" => l["label_hint"]
            }
          end

          if links.empty? && job_url.present?
            links = [
              { "url" => job_url.to_s, "type" => "job_posting", "description" => "Job posting" }
            ]
          end

          links.first(50)
        end

        def job_listing_steps(job_url, company_name, job_title)
          [
            {
              "step_id" => "upsert_job_listing_from_url",
              "action" => "upsert_job_listing_from_url",
              "target" => step_factory.target(selector: "none").merge("application_id" => nil),
              "params" => {
                "url" => job_url,
                "company_name" => company_name,
                "job_role_title" => job_title,
                "job_title" => job_title,
                "source" => { "synced_email_id" => email_id }
              },
              "preconditions" => [],
              "evidence" => [ "job posting: #{job_url}" ],
              "risk" => "low"
            },
            {
              "step_id" => "attach_job_listing_to_opportunity",
              "action" => "attach_job_listing_to_opportunity",
              "target" => step_factory.target(selector: "none").merge("application_id" => nil),
              "params" => {
                "url" => job_url,
                "source" => { "synced_email_id" => email_id }
              },
              "preconditions" => [],
              "evidence" => [ "job posting: #{job_url}" ],
              "risk" => "low"
            },
            {
              "step_id" => "enqueue_scrape_job_listing",
              "action" => "enqueue_scrape_job_listing",
              "target" => step_factory.target(selector: "none").merge("application_id" => nil),
              "params" => {
                "url" => job_url,
                "force" => false,
                "source" => { "synced_email_id" => email_id }
              },
              "preconditions" => [],
              "evidence" => [ "job posting: #{job_url}" ],
              "risk" => "low"
            }
          ]
        end
      end
    end
  end
end
