# frozen_string_literal: true

module Assistant
  module Memory
    class UserMemory < ApplicationRecord
      self.table_name = "assistant_user_memories"

      include Assistant::HasUuid

      belongs_to :user

      scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
    end
  end
end
