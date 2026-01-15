class AddEmailTrackingToCompanyFeedback < ActiveRecord::Migration[8.1]
  def change
    add_column :company_feedbacks, :source_email_id, :bigint
    add_column :company_feedbacks, :feedback_type, :string
    add_index :company_feedbacks, :source_email_id
  end
end
