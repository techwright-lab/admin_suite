# frozen_string_literal: true

module Signals
  module Decisioning
    # Semantic (non-schema) validation for DecisionPlan.
    #
    # These checks are used as guardrails before execution.
    class SemanticValidator
      def initialize(decision_input, decision_plan)
        @input = decision_input
        @plan = decision_plan
      end

      # @return [Array<Hash>] list of error hashes
      def errors
        errs = []
        body = input.dig("event", "body", "text").to_s
        body_norm = normalize_text(body)
        body_alnum = normalize_alnum(body)

        plan.fetch("plan", []).each do |step|
          evidence = Array(step["evidence"])
          next if step["action"] == "noop"
          if evidence.empty?
            errs << { "type" => "missing_evidence", "step_id" => step["step_id"] }
            next
          end
          evidence.each do |ev|
            next if ev.to_s.strip.empty?
            ev_text = ev.to_s

            urls = extract_urls(ev_text)
            if urls.any?
              urls.each do |url|
                next if url.strip.empty?
                # Allow trailing punctuation/brackets and minor formatting differences.
                unless body.match?(/#{Regexp.escape(url)}[\]\)\}\.,:;!?"]?/i)
                  errs << { "type" => "evidence_not_in_body", "step_id" => step["step_id"], "evidence" => ev_text }
                  break
                end
              end
              next
            end

            ev_norm = normalize_text(ev_text)
            ev_alnum = normalize_alnum(ev_text)
            unless body_norm.include?(ev_norm) || body_alnum.include?(ev_alnum)
              errs << { "type" => "evidence_not_in_body", "step_id" => step["step_id"], "evidence" => ev_text }
            end
          end
        end

        errs
      end

      def valid?
        errors.empty?
      end

      private

      attr_reader :input, :plan

      def normalize_text(text)
        text.to_s.downcase.gsub(/\s+/, " ").strip
      end

      def normalize_alnum(text)
        text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").gsub(/\s+/, " ").strip
      end

      def extract_urls(text)
        URI.extract(text.to_s, %w[http https])
      rescue StandardError
        []
      end
    end
  end
end
