# frozen_string_literal: true

AdminSuite.portal :ops do
  label "Ops Portal"
  icon "settings"
  color :amber
  order 10
  description "Content, Users, Email & Scraping Management"

  dashboard do
    row do
      health_panel "Scraping Pipeline",
        span: 4,
        status: lambda {
          recent = ScrapingAttempt.where("created_at > ?", 24.hours.ago)
          total = recent.count
          completed = recent.where(status: :completed).count
          stuck = recent.where(status: :processing).where("updated_at < ?", 30.minutes.ago).count
          rate = total > 0 ? (completed.to_f / total * 100).round : 0

          if stuck > 5 || (total > 10 && rate < 50)
            :critical
          elsif stuck > 0 || (total > 10 && rate < 80)
            :degraded
          else
            :healthy
          end
        },
        metrics: lambda {
          recent = ScrapingAttempt.where("created_at > ?", 24.hours.ago)
          total = recent.count
          completed = recent.where(status: :completed).count
          failed = recent.where(status: :failed).count
          stuck = recent.where(status: :processing).where("updated_at < ?", 30.minutes.ago).count
          rate = total > 0 ? (completed.to_f / total * 100).round : 0
          {
            "24h attempts" => total,
            "success rate" => "#{rate}%",
            "failed" => failed,
            "stuck" => stuck
          }
        }

      chart_panel "Scraping (7 days)",
        span: 4,
        data: lambda {
          (0..6).map do |i|
            date = i.days.ago.to_date
            count = ScrapingAttempt.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse
        }

      chart_panel "User Signups (7 days)",
        span: 4,
        data: lambda {
          (0..6).map do |i|
            date = i.days.ago.to_date
            count = User.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse
        }
    end

    row do
      stat_panel "Companies", -> { Company.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Job Roles", -> { JobRole.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Categories", -> { Category.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Skill Tags", -> { SkillTag.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Users", -> { User.count }, span: 2, variant: :mini, color: :green
      stat_panel "Applications", -> { InterviewApplication.count }, span: 2, variant: :mini, color: :cyan
    end

    row do
      stat_panel "Job Listings", -> { JobListing.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Resources", -> { Admin::Base::Resource.resources_for_portal(:ops).count }, span: 2, variant: :mini, color: :amber
    end

    row do
      cards_panel "Content Management",
        span: 12,
        resources: [
          { resource_name: "companies", label: "Companies", description: "Company profiles and associations", icon: "building-2", count: -> { Company.count } },
          { resource_name: "job_roles", label: "Job Roles", description: "Job titles and definitions", icon: "briefcase", count: -> { JobRole.count } },
          { resource_name: "categories", label: "Categories", description: "Job role categories", icon: "layers", count: -> { Category.count } },
          { resource_name: "skill_tags", label: "Skill Tags", description: "Skills and competencies", icon: "tag", count: -> { SkillTag.count } },
          { resource_name: "job_listings", label: "Job Listings", description: "Jobs content management", icon: "file-text", count: -> { JobListing.count } },
          { resource_name: "blog_posts", label: "Blog Posts", description: "Blog content management", icon: "pencil-line", count: -> { BlogPost.count } }
        ]
    end

    row do
      recent_panel "Recent Users",
        span: 6,
        scope: -> { User.order(created_at: :desc).limit(5) },
        view_all_path: ->(view) { view.resources_path(portal: :ops, resource_name: "users") }

      recent_panel "Recent Applications",
        span: 6,
        scope: -> { InterviewApplication.includes(:user, :company).order(created_at: :desc).limit(5) },
        view_all_path: ->(view) { view.resources_path(portal: :ops, resource_name: "interview_applications") }
    end
  end
end
