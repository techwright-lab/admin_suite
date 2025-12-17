class AddStrengthsAndDomainsToUserResumes < ActiveRecord::Migration[8.1]
  def change
    add_column :user_resumes, :strengths, :jsonb, null: false, default: []
    add_column :user_resumes, :domains, :jsonb, null: false, default: []
  end
end
