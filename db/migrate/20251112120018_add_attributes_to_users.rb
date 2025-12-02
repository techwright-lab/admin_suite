class AddAttributesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :bio, :text
    add_column :users, :current_role, :string
    add_column :users, :years_of_experience, :integer
    add_column :users, :target_roles, :text
    add_column :users, :linkedin_url, :string
    add_column :users, :github_url, :string
    add_column :users, :gitlab_url, :string
    add_column :users, :twitter_url, :string
    add_column :users, :portfolio_url, :string
  end
end
