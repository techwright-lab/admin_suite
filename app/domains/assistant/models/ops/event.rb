# frozen_string_literal: true

module Assistant
  module Ops
    class Event < ApplicationRecord
      self.table_name = "assistant_events"

      include Assistant::HasUuid

      SEVERITIES = %w[debug info warn error].freeze

      belongs_to :thread, class_name: "Assistant::ChatThread"

      validates :severity, inclusion: { in: SEVERITIES }
    end
  end
end
