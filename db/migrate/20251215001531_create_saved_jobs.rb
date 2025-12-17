class CreateSavedJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :opportunity, null: true, foreign_key: true
      t.string :url
      t.string :company_name
      t.string :job_role_title
      t.string :title
      t.text :notes
      t.datetime :converted_at

      t.timestamps
    end

    add_index :saved_jobs, :converted_at
    add_index :saved_jobs, [ :user_id, :created_at ]

    # Uniqueness: a user can only save a given opportunity once.
    add_index :saved_jobs,
      [ :user_id, :opportunity_id ],
      unique: true,
      where: "opportunity_id IS NOT NULL",
      name: "index_saved_jobs_on_user_and_opportunity_unique"

    # Uniqueness: a user can only save a given URL once.
    add_index :saved_jobs,
      [ :user_id, :url ],
      unique: true,
      where: "url IS NOT NULL",
      name: "index_saved_jobs_on_user_and_url_unique"

    # Ensure exactly one of opportunity_id or url is present.
    add_check_constraint :saved_jobs,
      "(opportunity_id IS NOT NULL) <> (url IS NOT NULL)",
      name: "chk_saved_jobs_exactly_one_source"
  end
end
