# frozen_string_literal: true

module Signals
  module Decisioning
    module Execution
      module Handlers
        class BaseHandler
          def initialize(synced_email)
            @synced_email = synced_email
          end

          private

          attr_reader :synced_email

          def app
            synced_email.interview_application
          end

          def resolve_round(target)
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
