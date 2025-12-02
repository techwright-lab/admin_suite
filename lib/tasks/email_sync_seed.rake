# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Load email sync test data (requires main seeds to be run first)"
    task email_sync: :environment do
      load Rails.root.join("db/seeds/email_sync_data.rb")
    end
  end
end

namespace :email_sync do
  desc "Reset and reload email sync test data"
  task reset: :environment do
    puts "Clearing email sync data..."
    SyncedEmail.destroy_all
    EmailSender.destroy_all
    ConnectedAccount.destroy_all

    puts "Reloading email sync test data..."
    load Rails.root.join("db/seeds/email_sync_data.rb")
  end

  desc "Show email sync statistics"
  task stats: :environment do
    puts "Email Sync Statistics"
    puts "=" * 50
    puts ""
    puts "Connected Accounts: #{ConnectedAccount.count}"
    puts "  - Google OAuth2: #{ConnectedAccount.google.count}"
    puts "  - Sync Enabled: #{ConnectedAccount.sync_enabled.count}"
    puts ""
    puts "Email Senders: #{EmailSender.count}"
    puts "  - Assigned: #{EmailSender.assigned.count}"
    puts "  - Auto-detected: #{EmailSender.auto_detected.count}"
    puts "  - Unassigned: #{EmailSender.unassigned.count}"
    puts "  - Verified: #{EmailSender.verified.count}"
    puts "  - By Type:"
    EmailSender::SENDER_TYPES.each do |type|
      count = EmailSender.where(sender_type: type).count
      puts "    - #{type}: #{count}"
    end
    puts ""
    puts "Synced Emails: #{SyncedEmail.count}"
    puts "  - Processed: #{SyncedEmail.processed.count}"
    puts "  - Needs Review: #{SyncedEmail.needs_review.count}"
    puts "  - Pending (all): #{SyncedEmail.pending.count}"
    puts "  - Ignored: #{SyncedEmail.ignored.count}"
    puts "  - Matched to Applications: #{SyncedEmail.matched.count}"
    puts "  - Unmatched: #{SyncedEmail.unmatched.count}"
    puts "  - By Type:"
    SyncedEmail::EMAIL_TYPES.each do |type|
      count = SyncedEmail.where(email_type: type).count
      puts "    - #{type}: #{count}" if count > 0
    end
  end
end
