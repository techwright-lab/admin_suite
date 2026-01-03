# Adds body_html column to store the full HTML content of synced emails
# This allows for proper email rendering with formatting, links, images, etc.
# body_preview stores plain text for search/display, body_html stores the original HTML
class AddBodyHtmlToSyncedEmails < ActiveRecord::Migration[8.1]
  def change
    add_column :synced_emails, :body_html, :text, comment: "Full HTML content of the email"
  end
end
