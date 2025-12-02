class AddSettingsToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :ai_feedback_analysis, :boolean, default: true
    add_column :user_preferences, :ai_interview_prep, :boolean, default: true
    add_column :user_preferences, :ai_insights_frequency, :string, default: "weekly"
    add_column :user_preferences, :email_weekly_digest, :boolean, default: true
    add_column :user_preferences, :email_interview_reminders, :boolean, default: true
    add_column :user_preferences, :data_retention_days, :integer, default: 0
  end
end
