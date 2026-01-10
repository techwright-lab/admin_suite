class AddSlugToSkillTags < ActiveRecord::Migration[8.1]
  def change
    add_column :skill_tags, :slug, :string
    add_index :skill_tags, :slug, unique: true
  end
end
