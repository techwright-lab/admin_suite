# frozen_string_literal: true

# Migration to create the developers table for TechWright SSO authentication
#
# Developers are separate from Users and authenticate via TechWright SSO
# to access the internal admin portal at /internal/developer/*
class CreateDevelopers < ActiveRecord::Migration[8.0]
  def change
    create_table :developers do |t|
      # TechWright identity
      t.string :techwright_uid, null: false
      t.string :email, null: false
      t.string :name

      # OAuth tokens (encrypted at rest via ActiveRecord encryption)
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at

      # Access control
      t.boolean :enabled, default: true, null: false

      # Audit fields
      t.datetime :last_login_at
      t.string :last_login_ip
      t.integer :login_count, default: 0

      t.timestamps
    end

    add_index :developers, :techwright_uid, unique: true
    add_index :developers, :email
    add_index :developers, :enabled
  end
end
