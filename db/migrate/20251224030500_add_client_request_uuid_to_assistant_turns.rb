# frozen_string_literal: true

class AddClientRequestUuidToAssistantTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_turns, :client_request_uuid, :uuid

    add_index :assistant_turns,
      %i[thread_id client_request_uuid],
      unique: true,
      where: "client_request_uuid IS NOT NULL",
      name: "idx_assistant_turns_thread_client_request_uuid"
  end
end
