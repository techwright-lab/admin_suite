# frozen_string_literal: true

class AddProviderStateToAssistantTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_turns, :provider_name, :string
    add_column :assistant_turns, :provider_state, :jsonb, null: false, default: {}

    add_index :assistant_turns, :provider_name
  end
end
