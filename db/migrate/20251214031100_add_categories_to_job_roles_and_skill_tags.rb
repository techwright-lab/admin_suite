class AddCategoriesToJobRolesAndSkillTags < ActiveRecord::Migration[8.1]
  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  class MigrationJobRole < ActiveRecord::Base
    self.table_name = "job_roles"
  end

  class MigrationSkillTag < ActiveRecord::Base
    self.table_name = "skill_tags"
  end

  def change
    rename_column :job_roles, :category, :legacy_category
    rename_column :skill_tags, :category, :legacy_category

    add_reference :job_roles, :category, foreign_key: true, index: true, null: true
    add_reference :skill_tags, :category, foreign_key: true, index: true, null: true

    reversible do |dir|
      dir.up do
        MigrationCategory.reset_column_information
        MigrationJobRole.reset_column_information
        MigrationSkillTag.reset_column_information

        MigrationJobRole.where.not(legacy_category: [ nil, "" ]).find_each do |jr|
          category = MigrationCategory.where(
            "LOWER(name) = ? AND kind = ?",
            jr.legacy_category.to_s.strip.downcase,
            0 # job_role
          ).first_or_create!(name: jr.legacy_category.to_s.strip, kind: 0)
          jr.update!(category_id: category.id)
        end

        MigrationSkillTag.where.not(legacy_category: [ nil, "" ]).find_each do |tag|
          category = MigrationCategory.where(
            "LOWER(name) = ? AND kind = ?",
            tag.legacy_category.to_s.strip.downcase,
            1 # skill_tag
          ).first_or_create!(name: tag.legacy_category.to_s.strip, kind: 1)
          tag.update!(category_id: category.id)
        end
      end
    end
  end
end
