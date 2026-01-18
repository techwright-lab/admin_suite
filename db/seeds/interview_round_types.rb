# frozen_string_literal: true

# Seeds for interview round types
# These are used to classify interview rounds by type, associated with departments

# Universal round types (available to all departments)
UNIVERSAL_ROUND_TYPES = [
  { name: "Phone Screen", slug: "phone_screen", description: "Initial recruiter/HR call to discuss background and fit", position: 0 },
  { name: "Behavioral", slug: "behavioral", description: "STAR method interview focusing on soft skills and past experiences", position: 10 },
  { name: "Hiring Manager", slug: "hiring_manager", description: "Interview with the hiring manager to discuss role and team", position: 20 },
  { name: "Team Fit", slug: "team_fit", description: "Culture and team fit assessment with potential teammates", position: 30 },
  { name: "Panel", slug: "panel", description: "Interview with multiple interviewers simultaneously", position: 40 },
  { name: "Executive", slug: "executive", description: "Final interview with senior leadership or executives", position: 50 },
  { name: "HR/Offer", slug: "hr_offer", description: "Final HR discussion including compensation and logistics", position: 60 }
].freeze

# Department-specific round types
# Maps department name to array of round types specific to that department
DEPARTMENT_ROUND_TYPES = {
  "Engineering" => [
    { name: "Coding", slug: "coding", description: "Live coding or pair programming technical assessment", position: 100 },
    { name: "System Design", slug: "system_design", description: "Architecture and system design discussion", position: 110 },
    { name: "Technical Deep Dive", slug: "technical_deep", description: "Domain-specific technical discussion or whiteboard session", position: 120 },
    { name: "Take Home", slug: "take_home", description: "Take-home assignment review and discussion", position: 130 },
    { name: "Code Review", slug: "code_review", description: "Review and discuss a code sample or project", position: 140 }
  ],
  "Product" => [
    { name: "Case Study", slug: "case_study", description: "Business case or product sense analysis", position: 200 },
    { name: "Product Strategy", slug: "product_strategy", description: "Product roadmap and strategic thinking discussion", position: 210 },
    { name: "Presentation", slug: "presentation", description: "Presenting work, portfolio, or case study results", position: 220 }
  ],
  "Design" => [
    { name: "Portfolio Review", slug: "portfolio_review", description: "Walkthrough and discussion of design portfolio", position: 300 },
    { name: "Design Challenge", slug: "design_challenge", description: "Live or take-home design exercise", position: 310 },
    { name: "Presentation", slug: "presentation_design", description: "Presenting design work or case study", position: 320 },
    { name: "Critique", slug: "critique", description: "Design critique session with team members", position: 330 }
  ],
  "Data Science" => [
    { name: "Coding", slug: "coding_ds", description: "Python/SQL coding for data problems", position: 400 },
    { name: "ML Deep Dive", slug: "ml_deep_dive", description: "Machine learning concepts and model discussion", position: 410 },
    { name: "Case Study", slug: "case_study_ds", description: "Data analysis or product analytics case", position: 420 },
    { name: "Statistics", slug: "statistics", description: "Statistical concepts and experimentation discussion", position: 430 }
  ],
  "DevOps/SRE" => [
    { name: "System Design", slug: "system_design_infra", description: "Infrastructure and reliability architecture discussion", position: 500 },
    { name: "Troubleshooting", slug: "troubleshooting", description: "Incident response and debugging scenarios", position: 510 },
    { name: "Coding", slug: "coding_devops", description: "Automation and scripting assessment", position: 520 }
  ],
  "Sales" => [
    { name: "Pitch/Demo", slug: "pitch_demo", description: "Sales pitch or product demonstration", position: 600 },
    { name: "Role Play", slug: "role_play_sales", description: "Sales role play scenario", position: 610 },
    { name: "Case Study", slug: "case_study_sales", description: "Sales strategy or account planning case", position: 620 }
  ],
  "Marketing" => [
    { name: "Case Study", slug: "case_study_marketing", description: "Marketing campaign or strategy case", position: 700 },
    { name: "Presentation", slug: "presentation_marketing", description: "Marketing portfolio or campaign presentation", position: 710 }
  ],
  "QA/Testing" => [
    { name: "Technical Assessment", slug: "qa_technical", description: "Testing methodology and automation assessment", position: 800 },
    { name: "Test Design", slug: "test_design", description: "Test case design and strategy discussion", position: 810 }
  ],
  "Security" => [
    { name: "Technical Assessment", slug: "security_technical", description: "Security concepts and vulnerability assessment", position: 900 },
    { name: "Threat Modeling", slug: "threat_modeling", description: "Threat modeling and security architecture discussion", position: 910 }
  ]
}.freeze

puts "Seeding interview round types..."

# First, ensure departments are seeded
load Rails.root.join("db/seeds/departments.rb") unless Category.departments.exists?

# Seed universal round types (no department association)
puts "  Seeding universal round types..."
UNIVERSAL_ROUND_TYPES.each do |rt|
  round_type = InterviewRoundType.find_or_initialize_by(slug: rt[:slug])
  round_type.assign_attributes(
    name: rt[:name],
    description: rt[:description],
    position: rt[:position],
    category: nil
  )
  round_type.save!
  puts "    - #{rt[:name]} (universal)"
end

# Seed department-specific round types
puts "  Seeding department-specific round types..."
DEPARTMENT_ROUND_TYPES.each do |dept_name, round_types|
  category = Category.find_by(name: dept_name, kind: :job_role)
  if category.nil?
    puts "    ! Skipping #{dept_name} - department not found"
    next
  end

  round_types.each do |rt|
    round_type = InterviewRoundType.find_or_initialize_by(slug: rt[:slug])
    round_type.assign_attributes(
      name: rt[:name],
      description: rt[:description],
      position: rt[:position],
      category: category
    )
    round_type.save!
    puts "    - #{rt[:name]} (#{dept_name})"
  end
end

total_count = InterviewRoundType.count
universal_count = InterviewRoundType.universal.count
puts "Seeded #{total_count} interview round types (#{universal_count} universal, #{total_count - universal_count} department-specific)"
