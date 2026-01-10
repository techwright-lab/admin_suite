# frozen_string_literal: true

# Seeds for departments (Categories with kind: job_role)
# These are used to categorize job roles by function/department

DEPARTMENTS = [
  { name: "Engineering", description: "Software engineering, development, and technical roles" },
  { name: "Product", description: "Product management, strategy, and ownership roles" },
  { name: "Design", description: "UI/UX design, visual design, and user research roles" },
  { name: "Data Science", description: "Data science, analytics, and machine learning roles" },
  { name: "DevOps/SRE", description: "Infrastructure, reliability, and platform engineering roles" },
  { name: "Sales", description: "Sales, business development, and account management roles" },
  { name: "Marketing", description: "Marketing, growth, and brand management roles" },
  { name: "Customer Success", description: "Customer success, support, and experience roles" },
  { name: "Finance", description: "Finance, accounting, and financial planning roles" },
  { name: "HR/People", description: "Human resources, talent, and people operations roles" },
  { name: "Legal", description: "Legal, compliance, and policy roles" },
  { name: "Operations", description: "Operations, logistics, and business operations roles" },
  { name: "Executive", description: "C-level and executive leadership roles" },
  { name: "Research", description: "Research, R&D, and scientific roles" },
  { name: "QA/Testing", description: "Quality assurance, testing, and SDET roles" },
  { name: "Security", description: "Information security, cybersecurity, and AppSec roles" },
  { name: "IT", description: "Information technology and IT administration roles" },
  { name: "Content", description: "Content creation, writing, and editorial roles" },
  { name: "Other", description: "Other roles not fitting into specific departments" }
].freeze

puts "Seeding departments (job_role categories)..."

DEPARTMENTS.each do |dept|
  category = Category.find_or_initialize_by(name: dept[:name], kind: :job_role)
  category.description = dept[:description] if category.respond_to?(:description=)
  category.save!
  puts "  - #{dept[:name]}"
end

puts "Seeded #{DEPARTMENTS.size} departments"
