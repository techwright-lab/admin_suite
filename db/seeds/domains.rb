# frozen_string_literal: true

# Seeds for professional domains/industries
# These are used for user targeting and resume analysis

DOMAINS = [
  { name: "FinTech", description: "Financial technology and digital banking" },
  { name: "SaaS", description: "Software as a Service products" },
  { name: "E-commerce", description: "Online retail and marketplaces" },
  { name: "Healthcare", description: "Healthcare, medical technology, and health services" },
  { name: "EdTech", description: "Education technology and online learning" },
  { name: "AI/ML", description: "Artificial intelligence and machine learning" },
  { name: "Cybersecurity", description: "Information security and cyber defense" },
  { name: "Gaming", description: "Video games, interactive entertainment, and esports" },
  { name: "Social Media", description: "Social networking and community platforms" },
  { name: "Enterprise Software", description: "Business software and enterprise solutions" },
  { name: "B2B", description: "Business-to-business products and services" },
  { name: "B2C", description: "Business-to-consumer products and services" },
  { name: "Marketplace", description: "Two-sided marketplaces and platform businesses" },
  { name: "Media/Entertainment", description: "Media, streaming, and entertainment" },
  { name: "Real Estate", description: "Real estate technology and property services" },
  { name: "Travel", description: "Travel, hospitality, and tourism technology" },
  { name: "Logistics", description: "Supply chain, logistics, and delivery" },
  { name: "Automotive", description: "Automotive, electric vehicles, and mobility" },
  { name: "CleanTech", description: "Clean energy and environmental technology" },
  { name: "AgTech", description: "Agriculture technology and food systems" },
  { name: "InsurTech", description: "Insurance technology" },
  { name: "LegalTech", description: "Legal technology and law practice management" },
  { name: "HRTech", description: "Human resources and talent management technology" },
  { name: "PropTech", description: "Property technology and real estate innovation" },
  { name: "Blockchain/Crypto", description: "Blockchain, cryptocurrency, and Web3" },
  { name: "IoT", description: "Internet of Things and connected devices" },
  { name: "Telecom", description: "Telecommunications and networking" },
  { name: "Government/GovTech", description: "Government technology and public sector" },
  { name: "Non-profit", description: "Non-profit organizations and social impact" },
  { name: "Consulting", description: "Professional services and consulting" },
  { name: "Retail", description: "Retail technology and in-store solutions" },
  { name: "Manufacturing", description: "Manufacturing and industrial technology" },
  { name: "Aerospace", description: "Aerospace, aviation, and space technology" },
  { name: "Defense", description: "Defense and military technology" },
  { name: "Biotech", description: "Biotechnology and life sciences" },
  { name: "Pharma", description: "Pharmaceutical and drug development" }
].freeze

puts "Seeding domains..."

DOMAINS.each do |domain_data|
  domain = Domain.find_or_initialize_by(name: domain_data[:name])
  domain.description = domain_data[:description]
  domain.save!
  puts "  - #{domain_data[:name]}"
end

puts "Seeded #{DOMAINS.size} domains"
