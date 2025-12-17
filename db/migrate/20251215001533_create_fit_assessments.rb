class CreateFitAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :fit_assessments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :fittable, polymorphic: true, null: false
      t.integer :score
      t.integer :status, null: false, default: 0
      t.datetime :computed_at
      t.string :algorithm_version
      t.string :inputs_digest
      t.jsonb :breakdown, null: false, default: {}

      t.timestamps
    end

    add_index :fit_assessments,
      [ :user_id, :fittable_type, :fittable_id ],
      unique: true,
      name: "index_fit_assessments_on_user_and_fittable_unique"

    add_index :fit_assessments, :computed_at
  end
end
