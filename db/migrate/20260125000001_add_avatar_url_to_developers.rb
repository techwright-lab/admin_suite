# frozen_string_literal: true

# Add avatar_url column to developers table
# This stores the profile picture URL from TechWright SSO
class AddAvatarUrlToDevelopers < ActiveRecord::Migration[8.0]
  def change
    add_column :developers, :avatar_url, :string
  end
end
