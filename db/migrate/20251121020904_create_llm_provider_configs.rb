class CreateLlmProviderConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_provider_configs do |t|
      t.string :name, null: false
      t.string :provider_type, null: false # openai, anthropic, ollama, gemini
      t.string :llm_model, null: false
      t.string :api_endpoint
      t.integer :max_tokens, default: 4096
      t.float :temperature, default: 0.0
      t.boolean :enabled, default: true, null: false
      t.integer :priority, default: 0, null: false # Lower number = higher priority
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :llm_provider_configs, :provider_type
    add_index :llm_provider_configs, :enabled
    add_index :llm_provider_configs, [:enabled, :priority]
  end
end
