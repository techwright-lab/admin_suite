class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :preferred_view, default: "kanban"
      t.string :timezone, default: "UTC"
      t.boolean :email_notifications, default: true
      t.boolean :ai_summary_enabled, default: true
      t.string :theme, default: "system"

      t.timestamps
    end
  end
end
