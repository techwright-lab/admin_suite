class AddFailedStepToScrapingAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :scraping_attempts, :failed_step, :string
  end
end
