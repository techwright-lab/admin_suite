class CreateSkillTags < ActiveRecord::Migration[8.1]
  def change
    create_table :skill_tags do |t|
      t.string :name, null: false
      t.string :category

      t.timestamps
    end

    add_index :skill_tags, :name, unique: true
  end
end
