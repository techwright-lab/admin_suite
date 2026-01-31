# frozen_string_literal: true

module Signals
  module Decisioning
    # Builds a schema-valid DecisionInput using the current application/email state.
    #
    # Note: This is a *builder* only. It does not write to the DB.
    class DecisionInputBuilder
      VERSION = "2026-01-27".freeze

      def initialize(synced_email)
        @synced_email = synced_email
      end

      def build(facts: nil)
        base = build_base
        app = synced_email.interview_application
        base.merge("facts" => (facts || build_fallback_facts(app)))
      end

      # Base DecisionInput without facts (used by EmailFacts extraction).
      def build_base
        app = synced_email.interview_application
        event = Signals::Facts::CanonicalEmailEventBuilder.new(synced_email).build

        {
          "version" => VERSION,
          "event" => event,
          "match" => build_match(app),
          "application" => app ? build_application_snapshot(app) : nil
        }
      end

      private

      attr_reader :synced_email

      def build_match(app)
        {
          "matched" => synced_email.matched?,
          "match_strategy" => nil,
          "interview_application_id" => app&.id,
          "confidence" => synced_email.matched? ? 0.5 : 0.0
        }
      end

      def build_application_snapshot(app)
        rounds = app.interview_rounds.ordered.last(10).map do |r|
          {
            "id" => r.id,
            "position" => r.position,
            "stage" => r.stage,
            "stage_name" => r.stage_name,
            "scheduled_at" => r.scheduled_at&.iso8601,
            "result" => r.result,
            "interviewer_name" => r.interviewer_name,
            "source_email_id" => r.source_email_id
          }
        end

        {
          "id" => app.id,
          "status" => app.status,
          "pipeline_stage" => app.pipeline_stage,
          "company" => {
            "id" => app.company_id,
            "name" => app.company&.name,
            "website" => app.company&.website
          },
          "job_role" => {
            "id" => app.job_role_id,
            "title" => app.job_role&.title
          },
          "rounds_recent" => rounds
        }
      end

      public

      def build_fallback_facts(app)
        email_type = synced_email.email_type.to_s
        kind = map_kind(email_type)

        {
          "extraction" => {
            "provider" => nil,
            "model" => nil,
            "confidence" => (synced_email.extraction_confidence || 0.0).to_f,
            "warnings" => []
          },
          "classification" => {
            "kind" => kind,
            "confidence" => kind == "unknown" ? 0.0 : 0.5,
            "evidence" => [synced_email.subject.to_s.presence || synced_email.snippet.to_s.presence || "classified"].compact
          },
          "entities" => {
            "company" => {
              "name" => synced_email.signal_company_name || app&.company&.name,
              "website" => synced_email.signal_company_website || app&.company&.website
            },
            "recruiter" => {
              "name" => synced_email.signal_recruiter_name,
              "email" => synced_email.signal_recruiter_email,
              "title" => synced_email.signal_recruiter_title
            },
            "job" => {
              "title" => synced_email.signal_job_title || app&.job_role&.title,
              "department" => synced_email.signal_job_department,
              "location" => synced_email.signal_job_location,
              "url" => synced_email.signal_job_url
            }
          },
          "action_links" => Array(synced_email.signal_action_links).map do |l|
            next unless l.is_a?(Hash)
            url = l["url"].to_s
            label = l["action_label"].to_s
            next if url.blank? || label.blank?
            { "url" => url, "action_label" => label, "priority" => (l["priority"] || 5).to_i }
          end.compact.first(20),
          "key_insights" => synced_email.extracted_data&.dig("key_insights"),
          "is_forwarded" => !!synced_email.extracted_data&.dig("is_forwarded"),
          "scheduling" => empty_scheduling,
          "round_feedback" => empty_round_feedback,
          "status_change" => status_change_stub(email_type)
        }
      end

      private

      def map_kind(email_type)
        case email_type
        when "scheduling", "interview_reminder" then "scheduling"
        when "interview_invite" then "interview_invite"
        when "round_feedback" then "round_feedback"
        when "rejection", "offer" then "status_update"
        when "application_confirmation" then "application_confirmation"
        when "recruiter_outreach" then "recruiter_outreach"
        when "assessment" then "interview_assessment"
        when "", nil then "unknown"
        else "other"
        end
      end

      def empty_scheduling
        {
          "is_scheduling_related" => false,
          "scheduled_at" => nil,
          "timezone_hint" => nil,
          "duration_minutes" => 0,
          "stage" => nil,
          "round_type" => nil,
          "stage_name" => nil,
          "interviewer_name" => nil,
          "interviewer_role" => nil,
          "video_link" => nil,
          "phone_number" => nil,
          "location" => nil,
          "is_rescheduled" => false,
          "is_cancelled" => false,
          "original_scheduled_at" => nil,
          "evidence" => []
        }
      end

      def empty_round_feedback
        {
          "has_round_feedback" => false,
          "result" => nil,
          "stage_mentioned" => nil,
          "round_type" => nil,
          "interviewer_mentioned" => nil,
          "date_mentioned" => nil,
          "feedback" => {
            "has_detailed_feedback" => false,
            "summary" => nil,
            "strengths" => [],
            "improvements" => [],
            "full_feedback_text" => nil
          },
          "next_steps" => {
            "has_next_round" => false,
            "next_round_type" => nil,
            "next_round_hint" => nil,
            "timeline_hint" => nil
          },
          "evidence" => []
        }
      end

      def status_change_stub(email_type)
        type = case email_type
        when "rejection" then "rejection"
        when "offer" then "offer"
        else "no_change"
        end

        {
          "has_status_change" => %w[rejection offer].include?(email_type),
          "type" => type,
          "is_final" => (email_type == "rejection") ? true : nil,
          "effective_date" => synced_email.email_date&.iso8601,
          "rejection_details" => { "reason" => nil, "stage_rejected_at" => nil, "is_generic" => false, "door_open" => false },
          "offer_details" => {
            "role_title" => nil,
            "department" => nil,
            "start_date" => nil,
            "response_deadline" => nil,
            "includes_compensation_info" => false,
            "compensation_hints" => nil,
            "next_steps" => nil
          },
          "feedback" => { "has_feedback" => false, "feedback_text" => nil, "is_constructive" => false },
          "evidence" => []
        }
      end
    end
  end
end

