# frozen_string_literal: true

class AddContextToHtmlScrapingLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :html_scraping_logs, :fetch_mode, :string
    add_column :html_scraping_logs, :board_type, :string
    add_column :html_scraping_logs, :extractor_kind, :string
    add_column :html_scraping_logs, :run_context, :string

    add_index :html_scraping_logs, :fetch_mode
    add_index :html_scraping_logs, :board_type
    add_index :html_scraping_logs, :extractor_kind
    add_index :html_scraping_logs, :run_context
  end
end
