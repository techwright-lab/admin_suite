# frozen_string_literal: true

puts "Seeding billing catalog (plans/features/entitlements)..."

Billing::SeedCatalogService.new.run!

puts "Billing catalog seeded."


