# frozen_string_literal: true

puts "Creating blog posts..."

seed_posts = [
  {
    slug: "welcome-to-gleania",
    title: "Welcome to Gleania",
    excerpt: "What we're building and why interview workflows deserve better tooling.",
    body: <<~MD,
      ## Why Gleania exists

      Job searching is already hard. The process becomes even harder when your data lives in ten places:

      - email threads
      - calendars
      - spreadsheets
      - notes apps

      Gleania brings it together so you can **track**, **reflect**, and **improve** with less effort.

      ### What’s next

      We'll be publishing practical guides on:

      - organizing your pipeline
      - follow-ups that work
      - extracting signal from recruiter outreach
    MD
    author_name: "Gleania Team",
    tag_list: "product, interviews",
    status: :published,
    published_at: 3.days.ago
  },
  {
    slug: "follow-up-templates-that-dont-feel-awkward",
    title: "Follow-up Templates That Don’t Feel Awkward",
    excerpt: "A simple set of follow-ups you can reuse, plus timing guidelines.",
    body: <<~MD,
      ## The rule of thumb

      Follow up when you have *new information* or when a promised timeline has passed.

      ## Templates

      **After a screen (24–48h):**

      - Thanks again for your time. I’m excited about the role and would love to know the next steps and timeline.

      **After a final round (48–72h):**

      - I enjoyed meeting the team. Happy to clarify anything else or share references if helpful.

      ## What not to do

      - Don’t send daily pings.
      - Don’t add pressure (“I need an answer today”).
    MD
    author_name: "Gleania Team",
    tag_list: "templates, job-search",
    status: :published,
    published_at: 7.days.ago
  }
]

seed_posts.each do |attrs|
  post = BlogPost.find_or_initialize_by(slug: attrs[:slug])
  post.assign_attributes(attrs)
  post.save!
end

puts "Blog posts: #{BlogPost.count}"


