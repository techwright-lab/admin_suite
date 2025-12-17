# frozen_string_literal: true

# Clear existing data
puts "Clearing existing data..."
ApplicationSkillTag.destroy_all
CompanyFeedback.destroy_all
InterviewRound.destroy_all
InterviewApplication.destroy_all
JobListing.destroy_all
UserTargetJobRole.destroy_all
UserTargetCompany.destroy_all
JobRole.destroy_all
Company.destroy_all
SkillTag.destroy_all
UserPreference.destroy_all
Session.destroy_all
User.destroy_all

load Rails.root.join("db/seeds/llm_provider_configs.rb")
load Rails.root.join("db/seeds/llm_prompts.rb")
load Rails.root.join("db/seeds/blog_posts.rb")

# Create companies
puts "Creating companies..."
companies = {
  techcorp: Company.create!(
    name: "TechCorp Inc",
    website: "https://techcorp.com",
    about: "Leading technology company focused on innovative solutions"
  ),
  startupxyz: Company.create!(
    name: "StartupXYZ",
    website: "https://startupxyz.io",
    about: "Fast-growing startup disrupting the industry"
  ),
  megacorp: Company.create!(
    name: "MegaCorp",
    website: "https://megacorp.com",
    about: "Fortune 500 enterprise technology company"
  ),
  innovatelabs: Company.create!(
    name: "InnovateLabs",
    website: "https://innovatelabs.com",
    about: "R&D focused company building cutting-edge products"
  )
}

# Create job roles
puts "Creating job roles..."
job_roles = {
  senior_swe: JobRole.create!(
    title: "Senior Software Engineer",
    category: "Engineering",
    description: "Senior-level software engineering position"
  ),
  fullstack: JobRole.create!(
    title: "Full Stack Developer",
    category: "Engineering",
    description: "Full stack development role"
  ),
  lead_engineer: JobRole.create!(
    title: "Lead Engineer",
    category: "Engineering",
    description: "Technical leadership position"
  ),
  backend_engineer: JobRole.create!(
    title: "Senior Backend Engineer",
    category: "Engineering",
    description: "Backend-focused engineering role"
  )
}

# Create a demo user
puts "Creating demo user..."
user = User.create!(
  email_address: "demo@gleania.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Demo User",
  bio: "Experienced software engineer looking for new opportunities",
  years_of_experience: 5,
  linkedin_url: "https://linkedin.com/in/demouser",
  github_url: "https://github.com/demouser",
  current_job_role: job_roles[:senior_swe],
  current_company: companies[:techcorp]
)

# Add target roles and companies
user.target_job_roles << [ job_roles[:lead_engineer], job_roles[:backend_engineer] ]
user.target_companies << [ companies[:startupxyz], companies[:innovatelabs] ]

# Update user preference (automatically created by after_create callback)
user.preference.update!(
  preferred_view: "kanban",
  theme: "system",
  email_notifications: true,
  ai_summary_enabled: true
)

# Create skill tags
puts "Creating skill tags..."
skills = [
  "System Design",
  "Problem Solving",
  "Communication",
  "Leadership",
  "React",
  "Ruby on Rails",
  "PostgreSQL",
  "API Design",
  "Testing",
  "DevOps"
]

skill_tags = skills.map do |skill|
  SkillTag.create!(name: skill, category: "Technical")
end

# Create job listings
puts "Creating job listings..."
job_listing1 = JobListing.create!(
  company: companies[:techcorp],
  job_role: job_roles[:senior_swe],
  title: "Senior Software Engineer - Platform Team",
  url: "https://techcorp.com/jobs/senior-swe",
  description: "Join our platform team to build scalable systems",
  requirements: "5+ years experience, Ruby on Rails, PostgreSQL",
  responsibilities: "Design and implement features, mentor junior developers",
  salary_min: 120000,
  salary_max: 180000,
  salary_currency: "USD",
  benefits: "Health insurance, 401k matching, unlimited PTO",
  location: "San Francisco, CA",
  remote_type: :hybrid,
  status: :active
)

job_listing2 = JobListing.create!(
  company: companies[:startupxyz],
  job_role: job_roles[:fullstack],
  title: "Full Stack Developer",
  url: "https://startupxyz.io/careers/fullstack",
  description: "Build amazing products with cutting-edge technology",
  requirements: "3+ years experience, React, Node.js or Rails",
  responsibilities: "Full stack development, feature ownership",
  salary_min: 100000,
  salary_max: 150000,
  salary_currency: "USD",
  location: "Remote",
  remote_type: :remote,
  status: :active
)

# Create sample interview applications
puts "Creating sample interview applications..."

# Application 1 - Applied stage
app1 = InterviewApplication.create!(
  user: user,
  company: companies[:techcorp],
  job_role: job_roles[:senior_swe],
  job_listing: job_listing1,
  status: :active,
  pipeline_stage: :applied,
  applied_at: 5.days.ago,
  notes: "Applied through company website. Looks like a great culture fit."
)
app1.skill_tags << [ skill_tags[0], skill_tags[1], skill_tags[4] ]

# Application 2 - Screening stage with rounds
app2 = InterviewApplication.create!(
  user: user,
  company: companies[:startupxyz],
  job_role: job_roles[:fullstack],
  job_listing: job_listing2,
  status: :active,
  pipeline_stage: :screening,
  applied_at: 2.weeks.ago,
  notes: "Recruiter reached out. Phone screen scheduled.",
  ai_summary: "Strong profile match for the role"
)
app2.skill_tags << [ skill_tags[4], skill_tags[5], skill_tags[7] ]

# Add interview round
round1 = InterviewRound.create!(
  interview_application: app2,
  stage: :screening,
  stage_name: "Phone Screen",
  scheduled_at: 3.days.from_now,
  duration_minutes: 30,
  interviewer_name: "Jane Smith",
  interviewer_role: "Recruiter",
  notes: "Initial screening call",
  result: :pending,
  position: 1
)

# Application 3 - Interviewing stage with multiple rounds
app3 = InterviewApplication.create!(
  user: user,
  company: companies[:megacorp],
  job_role: job_roles[:lead_engineer],
  status: :active,
  pipeline_stage: :interviewing,
  applied_at: 3.weeks.ago,
  notes: "Completed phone screen. Technical rounds in progress.",
  ai_summary: "Excellent technical performance so far"
)
app3.skill_tags << [ skill_tags[0], skill_tags[3], skill_tags[8] ]

# Add completed screening round
round2 = InterviewRound.create!(
  interview_application: app3,
  stage: :screening,
  stage_name: "Phone Screen",
  scheduled_at: 2.weeks.ago,
  completed_at: 2.weeks.ago,
  duration_minutes: 30,
  interviewer_name: "John Doe",
  interviewer_role: "Recruiter",
  notes: "Great conversation about background and experience",
  result: :passed,
  position: 1
)

# Add upcoming technical round
round3 = InterviewRound.create!(
  interview_application: app3,
  stage: :technical,
  stage_name: "Technical Interview",
  scheduled_at: 2.days.from_now,
  duration_minutes: 60,
  interviewer_name: "Sarah Johnson",
  interviewer_role: "Senior Engineer",
  notes: "System design and coding assessment",
  result: :pending,
  position: 2
)

# Application 4 - Offer stage
app4 = InterviewApplication.create!(
  user: user,
  company: companies[:innovatelabs],
  job_role: job_roles[:backend_engineer],
  status: :accepted,
  pipeline_stage: :offer,
  applied_at: 1.month.ago,
  notes: "Received and accepted offer! Starting next month.",
  ai_summary: "Successful interview process resulting in competitive offer acceptance."
)
app4.skill_tags << [ skill_tags[5], skill_tags[6], skill_tags[7] ]

# Add completed rounds
[
  { stage: :screening, name: "Phone Screen", interviewer: "Mike Brown", role: "Recruiter", duration: 30, position: 1 },
  { stage: :technical, name: "Technical Interview", interviewer: "Emily Chen", role: "Senior Engineer", duration: 60, position: 2 },
  { stage: :hiring_manager, name: "Hiring Manager Interview", interviewer: "David Lee", role: "Engineering Manager", duration: 45, position: 3 }
].each do |round_data|
  InterviewRound.create!(
    interview_application: app4,
    stage: round_data[:stage],
    stage_name: round_data[:name],
    scheduled_at: 3.weeks.ago,
    completed_at: 3.weeks.ago,
    duration_minutes: round_data[:duration],
    interviewer_name: round_data[:interviewer],
    interviewer_role: round_data[:role],
    notes: "Excellent performance",
    result: :passed,
    position: round_data[:position]
  )
end

# Add company feedback
CompanyFeedback.create!(
  interview_application: app4,
  feedback_text: "Excellent performance throughout the interview process. We're excited to have you join the team!",
  received_at: 1.week.ago,
  next_steps: "HR will reach out with onboarding details",
  self_reflection: "All the practice and reflection from previous interviews paid off. This is exactly the role I was looking for!"
)

puts "Seed data created successfully!"
puts ""
puts "Demo User Credentials:"
puts "Email: demo@gleania.com"
puts "Password: password123"
puts ""
puts "Statistics:"
puts "- #{Company.count} companies"
puts "- #{JobRole.count} job roles"
puts "- #{JobListing.count} job listings"
puts "- #{InterviewApplication.count} interview applications"
puts "- #{InterviewRound.count} interview rounds"
puts "- #{CompanyFeedback.count} company feedbacks"
puts "- #{SkillTag.count} skill tags"

# Load email sync test data
load Rails.root.join("db/seeds/email_sync_data.rb")
