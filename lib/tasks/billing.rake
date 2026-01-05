# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Seed billing catalog (plans/features/entitlements) safely and idempotently"
    task billing: :environment do
      load Rails.root.join("db/seeds/billing_catalog.rb")
    end
  end
end

namespace :billing do
  desc "Grant Admin/Developer billing access to a user by email (grants all features)"
  task :grant_admin_access, [ :email ] => :environment do |_, args|
    email = args[:email].to_s.strip.downcase
    abort "Usage: rake billing:grant_admin_access[email@example.com]" if email.blank?

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" if user.nil?

    Billing::AdminAccessService.new(user: user).grant!
    puts "Granted Admin/Developer billing access to #{email}"
  end

  desc "Revoke Admin/Developer billing access from a user by email"
  task :revoke_admin_access, [ :email ] => :environment do |_, args|
    email = args[:email].to_s.strip.downcase
    abort "Usage: rake billing:revoke_admin_access[email@example.com]" if email.blank?

    user = User.find_by(email_address: email)
    abort "User not found: #{email}" if user.nil?

    Billing::AdminAccessService.new(user: user).revoke!
    puts "Revoked Admin/Developer billing access from #{email}"
  end
end


