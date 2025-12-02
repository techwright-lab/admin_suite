# frozen_string_literal: true

# Seeds for email sync features testing
# Creates email senders, connected accounts, and synced emails

puts "Creating email sync test data..."

# Get the demo user (should exist from main seeds)
user = User.find_by(email_address: "demo@gleania.com")

unless user
  puts "Demo user not found. Run main seeds first: bin/rails db:seed"
  exit
end

# Clear existing email sync data
puts "Clearing existing email sync data..."
SyncedEmail.destroy_all
EmailSender.destroy_all
ConnectedAccount.destroy_all

# Get companies for reference
companies = Company.all.index_by(&:name)
applications = user.interview_applications.includes(:company, :job_role)

# Create a connected account for the user
puts "Creating connected account..."
connected_account = ConnectedAccount.create!(
  user: user,
  provider: "google_oauth2",
  uid: "123456789",
  email: user.email_address,
  access_token: "mock_access_token_#{SecureRandom.hex(16)}",
  refresh_token: "mock_refresh_token_#{SecureRandom.hex(16)}",
  expires_at: 1.hour.from_now,
  scopes: "email,https://www.googleapis.com/auth/gmail.readonly",
  sync_enabled: true,
  last_synced_at: 30.minutes.ago
)

puts "Creating email senders..."

# Create email senders with various states
email_senders_data = [
  # Assigned and verified senders
  {
    email: "recruiting@techcorp.com",
    name: "TechCorp Recruiting",
    domain: "techcorp.com",
    company: companies["TechCorp Inc"],
    verified: true,
    sender_type: "recruiter",
    email_count: 8,
    last_seen_at: 2.days.ago
  },
  {
    email: "jane.smith@techcorp.com",
    name: "Jane Smith",
    domain: "techcorp.com",
    company: companies["TechCorp Inc"],
    verified: true,
    sender_type: "hr",
    email_count: 3,
    last_seen_at: 5.days.ago
  },
  {
    email: "careers@startupxyz.io",
    name: "StartupXYZ Careers",
    domain: "startupxyz.io",
    company: companies["StartupXYZ"],
    verified: true,
    sender_type: "recruiter",
    email_count: 5,
    last_seen_at: 1.day.ago
  },
  {
    email: "hiring@megacorp.com",
    name: "MegaCorp Talent",
    domain: "megacorp.com",
    company: companies["MegaCorp"],
    verified: true,
    sender_type: "hr",
    email_count: 12,
    last_seen_at: 3.days.ago
  },

  # Auto-detected but not manually verified
  {
    email: "sarah.johnson@megacorp.com",
    name: "Sarah Johnson",
    domain: "megacorp.com",
    auto_detected_company: companies["MegaCorp"],
    verified: false,
    sender_type: "hiring_manager",
    email_count: 4,
    last_seen_at: 4.days.ago
  },
  {
    email: "david.lee@innovatelabs.com",
    name: "David Lee",
    domain: "innovatelabs.com",
    auto_detected_company: companies["InnovateLabs"],
    verified: false,
    sender_type: "hiring_manager",
    email_count: 6,
    last_seen_at: 1.week.ago
  },

  # Unassigned senders (need review)
  {
    email: "recruiter@greenhouse.io",
    name: "Greenhouse",
    domain: "greenhouse.io",
    verified: false,
    sender_type: "ats_system",
    email_count: 15,
    last_seen_at: 1.day.ago
  },
  {
    email: "noreply@lever.co",
    name: "Lever ATS",
    domain: "lever.co",
    verified: false,
    sender_type: "ats_system",
    email_count: 10,
    last_seen_at: 2.days.ago
  },
  {
    email: "talent@unknownstartup.com",
    name: "Unknown Startup HR",
    domain: "unknownstartup.com",
    verified: false,
    sender_type: "recruiter",
    email_count: 2,
    last_seen_at: 1.week.ago
  },
  {
    email: "john.doe@randomcompany.net",
    name: "John Doe",
    domain: "randomcompany.net",
    verified: false,
    sender_type: "unknown",
    email_count: 1,
    last_seen_at: 2.weeks.ago
  },
  {
    email: "interview@newtech.ai",
    name: "NewTech AI Recruiting",
    domain: "newtech.ai",
    verified: false,
    sender_type: "recruiter",
    email_count: 3,
    last_seen_at: 3.days.ago
  },
  {
    email: "hr@bigfinance.com",
    name: "Big Finance HR",
    domain: "bigfinance.com",
    verified: false,
    sender_type: "hr",
    email_count: 4,
    last_seen_at: 5.days.ago
  }
]

email_senders = {}
email_senders_data.each do |data|
  sender = EmailSender.create!(
    email: data[:email],
    name: data[:name],
    domain: data[:domain],
    company: data[:company],
    auto_detected_company: data[:auto_detected_company],
    verified: data[:verified],
    sender_type: data[:sender_type],
    email_count: data[:email_count],
    last_seen_at: data[:last_seen_at]
  )
  email_senders[data[:email]] = sender
end

puts "Creating synced emails..."

# Helper to generate realistic Gmail-like IDs
def generate_gmail_id
  SecureRandom.hex(8)
end

def generate_thread_id
  SecureRandom.hex(8)
end

# Get applications by company
app_techcorp = applications.find { |a| a.company.name == "TechCorp Inc" }
app_startupxyz = applications.find { |a| a.company.name == "StartupXYZ" }
app_megacorp = applications.find { |a| a.company.name == "MegaCorp" }
app_innovatelabs = applications.find { |a| a.company.name == "InnovateLabs" }

# Thread IDs for email conversations
techcorp_thread_id = generate_thread_id
startupxyz_thread_id = generate_thread_id
megacorp_thread_id = generate_thread_id
innovatelabs_thread_id = generate_thread_id

synced_emails_data = [
  # TechCorp emails (app1 - Applied stage) - Threaded conversation
  {
    application: app_techcorp,
    sender: email_senders["recruiting@techcorp.com"],
    subject: "Application Received - Senior Software Engineer",
    snippet: "Thank you for applying to TechCorp Inc. We have received your application for the Senior Software Engineer position...",
    body_preview: "Thank you for applying to TechCorp Inc!\n\nWe have received your application for the Senior Software Engineer position on our Platform Team. Our recruiting team is currently reviewing applications and will be in touch within the next 1-2 weeks.\n\nBest regards,\nTechCorp Recruiting",
    email_date: 5.days.ago,
    email_type: "application_confirmation",
    status: "processed",
    thread_id: techcorp_thread_id
  },
  {
    application: app_techcorp,
    sender: email_senders["jane.smith@techcorp.com"],
    subject: "Re: Application Received - Senior Software Engineer",
    snippet: "Hi, I'm reaching out regarding your application. We'd like to schedule an initial phone screening...",
    body_preview: "Hi!\n\nI'm Jane Smith from the TechCorp recruiting team. I've reviewed your application for the Senior Software Engineer role and I'm impressed with your background.\n\nWe'd like to schedule an initial phone screening at your earliest convenience. The call should take about 30 minutes.\n\nPlease let me know your availability for next week.\n\nBest,\nJane",
    email_date: 3.days.ago,
    email_type: "interview_invite",
    status: "processed",
    thread_id: techcorp_thread_id
  },
  {
    application: app_techcorp,
    sender: email_senders["jane.smith@techcorp.com"],
    subject: "Re: Application Received - Senior Software Engineer",
    snippet: "Great! I've scheduled your phone screen for Tuesday at 2pm PST. You'll receive a calendar invite shortly...",
    body_preview: "Great! Thanks for getting back to me so quickly.\n\nI've scheduled your phone screen for Tuesday at 2pm PST. You'll receive a calendar invite shortly with the video call link.\n\nThe call will be with me, and we'll discuss your background, experience, and what you're looking for in your next role.\n\nLooking forward to speaking with you!\n\nBest,\nJane",
    email_date: 2.days.ago,
    email_type: "scheduling",
    status: "processed",
    thread_id: techcorp_thread_id
  },

  # StartupXYZ emails (app2 - Screening stage) - Threaded conversation
  {
    application: app_startupxyz,
    sender: email_senders["careers@startupxyz.io"],
    subject: "Your Application to StartupXYZ",
    snippet: "Thanks for your interest in StartupXYZ! We're excited to review your application for Full Stack Developer...",
    body_preview: "Hi there!\n\nThanks for your interest in joining StartupXYZ! We're excited to review your application for the Full Stack Developer position.\n\nWe're a fast-growing team and we love passionate developers like yourself.\n\nStay tuned!",
    email_date: 2.weeks.ago,
    email_type: "application_confirmation",
    status: "processed",
    thread_id: startupxyz_thread_id
  },
  {
    application: app_startupxyz,
    sender: email_senders["careers@startupxyz.io"],
    subject: "Re: Your Application to StartupXYZ",
    snippet: "Great news! We'd love to chat with you about the Full Stack Developer role. Are you available this week?",
    body_preview: "Great news!\n\nWe'd love to chat with you about the Full Stack Developer role at StartupXYZ. Are you available for a 30-minute call this week?\n\nHere's the Calendly link to book a time: calendly.com/startupxyz/interview",
    email_date: 10.days.ago,
    email_type: "interview_invite",
    status: "processed",
    thread_id: startupxyz_thread_id
  },
  {
    application: app_startupxyz,
    sender: email_senders["careers@startupxyz.io"],
    subject: "Re: Your Application to StartupXYZ",
    snippet: "Just a friendly reminder about your phone screen tomorrow at 2pm PST...",
    body_preview: "Hi!\n\nJust a friendly reminder about your phone screen tomorrow at 2pm PST with our recruiter.\n\nLooking forward to speaking with you!",
    email_date: 4.days.ago,
    email_type: "interview_reminder",
    status: "processed",
    thread_id: startupxyz_thread_id
  },

  # MegaCorp emails (app3 - Interviewing stage)
  {
    application: app_megacorp,
    sender: email_senders["hiring@megacorp.com"],
    subject: "MegaCorp - Application Confirmation",
    snippet: "Your application for Lead Engineer at MegaCorp has been received. Our team will review...",
    body_preview: "Dear Applicant,\n\nYour application for the Lead Engineer position at MegaCorp has been received and is under review.\n\nRegards,\nMegaCorp Talent Team",
    email_date: 3.weeks.ago,
    email_type: "application_confirmation",
    status: "processed"
  },
  {
    application: app_megacorp,
    sender: email_senders["hiring@megacorp.com"],
    subject: "Phone Screen Completed - Next Steps",
    snippet: "Congratulations! You've passed the initial phone screen. We'd like to invite you to a technical interview...",
    body_preview: "Congratulations!\n\nYou've successfully completed the phone screen for the Lead Engineer position. The team was impressed with your communication and experience.\n\nWe'd like to invite you to the next round - a technical interview with our engineering team.\n\nPlease confirm your availability.",
    email_date: 2.weeks.ago,
    email_type: "interview_invite",
    status: "processed"
  },
  {
    application: app_megacorp,
    sender: email_senders["sarah.johnson@megacorp.com"],
    subject: "Technical Interview Details - MegaCorp",
    snippet: "Hi! I'm Sarah, and I'll be conducting your technical interview. Here are the details...",
    body_preview: "Hi!\n\nI'm Sarah Johnson, a Senior Engineer at MegaCorp. I'll be conducting your technical interview scheduled for next week.\n\nThe interview will cover:\n- System design discussion\n- Coding exercise\n- Q&A about our tech stack\n\nPlease come prepared with questions about our engineering culture!",
    email_date: 5.days.ago,
    email_type: "scheduling",
    status: "processed"
  },

  # InnovateLabs emails (app4 - Offer stage)
  {
    application: app_innovatelabs,
    sender: email_senders["david.lee@innovatelabs.com"],
    subject: "Offer Letter - Senior Backend Engineer at InnovateLabs",
    snippet: "We are thrilled to extend an offer for the Senior Backend Engineer position at InnovateLabs...",
    body_preview: "Dear Candidate,\n\nWe are thrilled to extend an official offer for the Senior Backend Engineer position at InnovateLabs!\n\nAttached please find your offer letter with details on compensation, benefits, and start date.\n\nPlease review and let us know if you have any questions. We're excited to have you join our team!\n\nBest,\nDavid Lee\nEngineering Manager",
    email_date: 10.days.ago,
    email_type: "offer",
    status: "processed"
  },
  {
    application: app_innovatelabs,
    sender: email_senders["david.lee@innovatelabs.com"],
    subject: "Re: Offer Acceptance - Welcome to InnovateLabs!",
    snippet: "Fantastic news! We're so happy you've accepted our offer. HR will be reaching out with onboarding...",
    body_preview: "Fantastic news!\n\nWe're so happy you've accepted our offer to join InnovateLabs as a Senior Backend Engineer!\n\nHR will be reaching out shortly with onboarding paperwork and next steps.\n\nLooking forward to working with you!",
    email_date: 1.week.ago,
    email_type: "follow_up",
    status: "processed"
  },

  # Unmatched emails (needs review)
  {
    application: nil,
    sender: email_senders["recruiter@greenhouse.io"],
    subject: "Your application status update",
    snippet: "An update on your recent application submitted through Greenhouse...",
    body_preview: "Hi,\n\nThis is an automated update regarding your recent application submitted through Greenhouse.\n\nStatus: Under Review",
    email_date: 1.day.ago,
    email_type: "other",
    status: "pending",
    detected_company: nil
  },
  {
    application: nil,
    sender: email_senders["noreply@lever.co"],
    subject: "Application Update - Software Engineer",
    snippet: "Your application for Software Engineer has been updated...",
    body_preview: "Your application for Software Engineer has been updated.\n\nPlease log in to Lever to view details.",
    email_date: 2.days.ago,
    email_type: "other",
    status: "pending",
    detected_company: nil
  },
  {
    application: nil,
    sender: email_senders["talent@unknownstartup.com"],
    subject: "Exciting Opportunity at Unknown Startup",
    snippet: "We came across your profile and think you'd be a great fit for our Engineering team...",
    body_preview: "Hi!\n\nWe came across your profile and think you'd be a great fit for our Engineering team at Unknown Startup.\n\nWe're building something exciting in the AI space and would love to chat!",
    email_date: 1.week.ago,
    email_type: "interview_invite",
    status: "pending",
    detected_company: "Unknown Startup"
  },
  {
    application: nil,
    sender: email_senders["interview@newtech.ai"],
    subject: "Interview Invitation - NewTech AI",
    snippet: "We'd like to invite you for an interview at NewTech AI for the Senior Developer position...",
    body_preview: "Hi!\n\nWe've reviewed your application and would like to invite you for an interview at NewTech AI.\n\nAre you available next week for a video call?",
    email_date: 3.days.ago,
    email_type: "interview_invite",
    status: "pending",
    detected_company: "NewTech AI"
  },
  {
    application: nil,
    sender: email_senders["hr@bigfinance.com"],
    subject: "Thank you for your interest - Big Finance",
    snippet: "Thank you for applying to Big Finance. Unfortunately, we have decided to move forward with other candidates...",
    body_preview: "Dear Applicant,\n\nThank you for your interest in the Software Engineer position at Big Finance.\n\nAfter careful consideration, we have decided to move forward with other candidates whose experience more closely matches our current needs.\n\nWe appreciate your time and wish you the best in your job search.",
    email_date: 5.days.ago,
    email_type: "rejection",
    status: "pending",
    detected_company: "Big Finance"
  }
]

synced_emails_data.each do |data|
  # Use predefined thread_id if provided, otherwise generate a new one
  email_thread_id = data[:thread_id] || generate_thread_id

  SyncedEmail.create!(
    user: user,
    connected_account: connected_account,
    interview_application: data[:application],
    email_sender: data[:sender],
    gmail_id: generate_gmail_id,
    thread_id: email_thread_id,
    subject: data[:subject],
    from_email: data[:sender].email,
    from_name: data[:sender].name,
    email_date: data[:email_date],
    snippet: data[:snippet],
    body_preview: data[:body_preview],
    status: data[:status],
    email_type: data[:email_type],
    detected_company: data[:detected_company] || data[:application]&.company&.name,
    labels: [ "INBOX", "IMPORTANT" ].sample(rand(1..2)),
    metadata: { synced_at: Time.current.iso8601 }
  )
end

# Create an admin user if not exists
puts "Ensuring admin user exists..."
admin = User.find_or_create_by!(email_address: "admin@gleania.com") do |u|
  u.password = "admin123"
  u.password_confirmation = "admin123"
  u.name = "Admin User"
  u.is_admin = true
end
admin.update!(is_admin: true) unless admin.admin?

puts ""
puts "Email sync test data created successfully!"
puts ""
puts "Statistics:"
puts "- #{ConnectedAccount.count} connected accounts"
puts "- #{EmailSender.count} email senders"
puts "  - #{EmailSender.assigned.count} assigned to companies"
puts "  - #{EmailSender.auto_detected.count} auto-detected"
puts "  - #{EmailSender.unassigned.count} unassigned (need review)"
puts "  - #{EmailSender.verified.count} verified"
puts "- #{SyncedEmail.count} synced emails"
puts "  - #{SyncedEmail.processed.count} processed"
puts "  - #{SyncedEmail.needs_review.count} needs review"
puts "  - #{SyncedEmail.where.not(interview_application_id: nil).count} matched to applications"
puts ""
puts "Admin User Credentials:"
puts "Email: admin@gleania.com"
puts "Password: admin123"
