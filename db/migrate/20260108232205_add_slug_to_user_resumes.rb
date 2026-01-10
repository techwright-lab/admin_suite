class AddSlugToUserResumes < ActiveRecord::Migration[8.1]
  def change
    add_column :user_resumes, :slug, :string
    add_index :user_resumes, :slug, unique: true
  end
end
