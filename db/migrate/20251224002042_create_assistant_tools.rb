class CreateAssistantTools < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_tools do |t|
      t.string :tool_key, null: false
      t.string :name, null: false
      t.text :description, null: false, default: ""
      t.boolean :enabled, null: false, default: true
      t.string :risk_level, null: false, default: "read_only"
      t.boolean :requires_confirmation, null: false, default: false
      t.jsonb :arg_schema, null: false, default: {}
      t.integer :timeout_ms, null: false, default: 5_000
      t.jsonb :rate_limit, null: false, default: {}
      t.string :executor_class, null: false

      t.timestamps
    end

    add_index :assistant_tools, :tool_key, unique: true
    add_index :assistant_tools, :enabled
  end
end
