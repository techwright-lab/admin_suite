# frozen_string_literal: true

# Adds interview_round_type association to interview_rounds for granular type classification.
# Nullable to allow existing rounds without a type assignment.
class AddInterviewRoundTypeToInterviewRounds < ActiveRecord::Migration[8.1]
  def change
    add_reference :interview_rounds, :interview_round_type, null: true, foreign_key: true
  end
end
