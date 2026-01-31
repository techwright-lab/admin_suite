# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      # Fail-closed evaluator for plan preconditions.
      #
      # IMPORTANT:
      # - This does NOT eval Ruby.
      # - Only known predicates are supported.
      # - Unknown predicates fail closed (skip step).
      class PreconditionEvaluator
        class << self
          def evaluate_all(preconditions, synced_email:, step:)
            preds = Array(preconditions).map(&:to_s).map(&:strip).reject(&:blank?)
            return { ok: true, failed: [], unknown: [] } if preds.empty?

            failed = []
            unknown = []

            preds.each do |pred|
              res = evaluate(pred, synced_email: synced_email, step: step)
              if res == :unknown
                unknown << pred
                failed << pred
              elsif res == false
                failed << pred
              end
            end

            { ok: failed.empty?, failed: failed, unknown: unknown }
          end

          def evaluate(predicate, synced_email:, step:)
            pred = predicate.to_s.strip

            return synced_email.matched? if pred == "match.matched == true"

            if (m = pred.match(/\Aapplication\.pipeline_stage != (\w+)\z/))
              app = synced_email.interview_application
              return false unless app
              return app.pipeline_stage.to_s != m[1]
            end

            if (m = pred.match(/\Aapplication\.pipeline_stage == (\w+)\z/))
              app = synced_email.interview_application
              return false unless app
              return app.pipeline_stage.to_s == m[1]
            end

            if (m = pred.match(/\Aapplication\.status == (\w+)\z/))
              app = synced_email.interview_application
              return false unless app
              return app.status.to_s == m[1]
            end

            if pred == "application.company_feedback == null"
              app = synced_email.interview_application
              return false unless app
              return app.company_feedback.nil?
            end

            if pred == "application.rounds_recent.any(result==pending) == true"
              app = synced_email.interview_application
              return false unless app
              return app.interview_rounds.where(result: :pending).exists?
            end

            if pred == "round.interview_feedback == null"
              round = resolve_round(synced_email, step["target"] || {})
              return false unless round
              return round.interview_feedback.nil?
            end

            :unknown
          end

          private

          def resolve_round(synced_email, target)
            app = synced_email.interview_application
            return nil unless app

            sel = target.dig("round", "selector")
            case sel
            when "by_id"
              id = target.dig("round", "id")
              app.interview_rounds.find_by(id: id)
            when "latest_pending"
              app.interview_rounds.where(result: :pending).order(scheduled_at: :desc).first
            when "latest"
              app.interview_rounds.ordered.last
            else
              nil
            end
          end
        end
      end
    end
  end
end
