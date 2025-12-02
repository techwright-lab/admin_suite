class CreateInterviewSkillTags < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_skill_tags do |t|
      t.references :interview, null: false, foreign_key: true
      t.references :skill_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :interview_skill_tags, [ :interview_id, :skill_tag_id ], unique: true
  end
end
