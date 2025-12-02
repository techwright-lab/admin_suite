class CreateExtractionPromptTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :extraction_prompt_templates do |t|
      t.string :name, null: false
      t.text :description
      t.text :prompt_template, null: false
      t.boolean :active, default: false, null: false
      t.integer :version, default: 1, null: false

      t.timestamps
    end

    add_index :extraction_prompt_templates, :active
    add_index :extraction_prompt_templates, [:active, :version]
  end
end
