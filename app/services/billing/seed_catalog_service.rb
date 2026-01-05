# frozen_string_literal: true

module Billing
  # Seeds the billing catalog (plans, features, entitlements) in an idempotent way.
  #
  # This is safe to run multiple times and in any environment.
  #
  # Usage:
  #   Billing::SeedCatalogService.new.run!
  class SeedCatalogService
    # @return [void]
    def run!
      Billing::Plan.transaction do
        upsert_features!
        upsert_plans!
        upsert_plan_entitlements!
      end

      Billing::Catalog.purge_cache!
    end

    private

    def upsert_features!
      features.each do |attrs|
        feature = Billing::Feature.find_or_initialize_by(key: attrs.fetch(:key))
        feature.assign_attributes(attrs.except(:key))
        feature.save!
      end
    end

    def upsert_plans!
      plans.each do |attrs|
        plan = Billing::Plan.find_or_initialize_by(key: attrs.fetch(:key))
        plan.assign_attributes(attrs.except(:key))
        plan.save!
      end
    end

    def upsert_plan_entitlements!
      plans_by_key = Billing::Plan.where(key: plans.map { |p| p[:key] }).index_by(&:key)
      features_by_key = Billing::Feature.where(key: features.map { |f| f[:key] }).index_by(&:key)

      plan_entitlements.each do |row|
        plan = plans_by_key.fetch(row.fetch(:plan_key))
        feature = features_by_key.fetch(row.fetch(:feature_key))

        ent = Billing::PlanEntitlement.find_or_initialize_by(plan: plan, feature: feature)
        ent.enabled = row.fetch(:enabled, true)
        ent.limit = row[:limit]
        ent.save!
      end
    end

    def features
      [
        { key: "cv_parsing_basic", name: "CV parsing (basic)", kind: "boolean", description: "Basic CV parsing", unit: nil },
        { key: "cv_parsing_full", name: "CV parsing (full)", kind: "boolean", description: "Full CV intelligence extraction", unit: nil },
        { key: "skill_domain_extraction_limited", name: "Career signal extraction (limited)", kind: "boolean", description: "Limited skills/domains extraction", unit: nil },
        { key: "skill_domain_extraction_full", name: "Career signal extraction (full)", kind: "boolean", description: "Full skills/domains/seniority extraction", unit: nil },

        { key: "interviews", name: "Interview tracking quota", kind: "quota", description: "Number of interview rounds/applications allowed", unit: "interviews" },
        { key: "ai_summaries", name: "AI summaries quota", kind: "quota", description: "AI summaries and synthesis quota", unit: "summaries" },

        { key: "pattern_detection", name: "Pattern detection", kind: "boolean", description: "Themes over time / improvement patterns", unit: nil },
        { key: "cv_feedback_comparison", name: "CV ↔ interview comparison", kind: "boolean", description: "Cross-analysis between CV and interviews/feedback", unit: nil },
        { key: "cv_feedback_comparison_enhanced", name: "CV ↔ interview comparison (enhanced)", kind: "boolean", description: "Deeper cross-analysis for Sprint", unit: nil },

        { key: "assistant_access", name: "Assistant access", kind: "boolean", description: "Context-aware assistant access", unit: nil },
        { key: "assistant_priority", name: "Assistant priority", kind: "boolean", description: "Priority assistant depth/processing", unit: nil },
        { key: "background_processing_priority", name: "Priority background processing", kind: "boolean", description: "Priority background processing", unit: nil },

        { key: "insight_export", name: "Insight export", kind: "boolean", description: "Export insights", unit: nil },

        # Interview preparation (application-specific coaching)
        { key: "interview_prepare_access", name: "Interview prepare access", kind: "boolean", description: "Access to the Prepare tab coaching experience", unit: nil },
        { key: "interview_prepare_refreshes", name: "Interview prepare refresh quota", kind: "quota", description: "Prep pack refresh quota", unit: "refreshes" },

        # Internal feature used by the 72-hour trial grant.
        { key: "pro_trial_access", name: "Pro trial access", kind: "boolean", description: "Unlocked during earned Pro trial window", unit: nil }
      ]
    end

    def plans
      [
        {
          key: "free",
          name: "Free — Reflect",
          description: "Trust & habit-building tier",
          plan_type: "free",
          interval: nil,
          amount_cents: 0,
          currency: "eur",
          highlighted: false,
          published: true,
          sort_order: 0,
          metadata: {
            pricing_features: [
              "Upload & parse CV (basic)",
              "Manual interview tracking (limited)",
              "Feedback journal (never gated)",
              "Basic AI summaries (low quota)",
              "Simple strengths & improvement tags"
            ]
          }
        },
        {
          key: "pro_monthly",
          name: "Pro — Grow",
          description: "Understand your professional profile — and improve it through every interview.",
          plan_type: "recurring",
          interval: "month",
          amount_cents: 1200,
          currency: "eur",
          highlighted: true,
          published: true,
          sort_order: 10,
          metadata: {
            pricing_features: [
              "Everything in Free",
              "Unlimited interviews & feedback entries",
              "Full career signal extraction",
              "Experience-backed insights over time",
              "Assistant access (fair use)"
            ]
          }
        },
        {
          key: "sprint_one_time",
          name: "Sprint — Interview Focus",
          description: "A focused month of clarity while you’re actively interviewing.",
          plan_type: "one_time",
          interval: nil,
          amount_cents: 2500,
          currency: "eur",
          highlighted: false,
          published: true,
          sort_order: 20,
          metadata: {
            pricing_features: [
              "Everything in Pro",
              "Higher AI limits",
              "Deeper CV ↔ interview cross-analysis",
              "Faster insight refresh",
              "Priority background processing"
            ]
          }
        },
        {
          key: "admin_developer",
          name: "Admin/Developer",
          description: "Internal plan for staff/admin access (not customer-facing).",
          plan_type: "free",
          interval: nil,
          amount_cents: 0,
          currency: "eur",
          highlighted: false,
          published: false,
          sort_order: 999,
          metadata: {}
        }
      ]
    end

    def plan_entitlements
      [
        # Free
        { plan_key: "free", feature_key: "cv_parsing_basic", enabled: true },
        { plan_key: "free", feature_key: "cv_parsing_full", enabled: false },
        { plan_key: "free", feature_key: "skill_domain_extraction_limited", enabled: true },
        { plan_key: "free", feature_key: "skill_domain_extraction_full", enabled: false },
        { plan_key: "free", feature_key: "interviews", enabled: true, limit: 5 },
        { plan_key: "free", feature_key: "ai_summaries", enabled: true, limit: 5 },
        { plan_key: "free", feature_key: "pattern_detection", enabled: false },
        { plan_key: "free", feature_key: "cv_feedback_comparison", enabled: false },
        { plan_key: "free", feature_key: "cv_feedback_comparison_enhanced", enabled: false },
        { plan_key: "free", feature_key: "assistant_access", enabled: false },
        { plan_key: "free", feature_key: "assistant_priority", enabled: false },
        { plan_key: "free", feature_key: "background_processing_priority", enabled: false },
        { plan_key: "free", feature_key: "insight_export", enabled: false },
        { plan_key: "free", feature_key: "interview_prepare_access", enabled: false },
        { plan_key: "free", feature_key: "interview_prepare_refreshes", enabled: true, limit: 0 },

        # Pro
        { plan_key: "pro_monthly", feature_key: "cv_parsing_basic", enabled: true },
        { plan_key: "pro_monthly", feature_key: "cv_parsing_full", enabled: true },
        { plan_key: "pro_monthly", feature_key: "skill_domain_extraction_limited", enabled: true },
        { plan_key: "pro_monthly", feature_key: "skill_domain_extraction_full", enabled: true },
        { plan_key: "pro_monthly", feature_key: "interviews", enabled: true, limit: nil },
        { plan_key: "pro_monthly", feature_key: "ai_summaries", enabled: true, limit: 50 },
        { plan_key: "pro_monthly", feature_key: "pattern_detection", enabled: true },
        { plan_key: "pro_monthly", feature_key: "cv_feedback_comparison", enabled: true },
        { plan_key: "pro_monthly", feature_key: "cv_feedback_comparison_enhanced", enabled: false },
        { plan_key: "pro_monthly", feature_key: "assistant_access", enabled: true },
        { plan_key: "pro_monthly", feature_key: "assistant_priority", enabled: false },
        { plan_key: "pro_monthly", feature_key: "background_processing_priority", enabled: false },
        { plan_key: "pro_monthly", feature_key: "insight_export", enabled: true },
        { plan_key: "pro_monthly", feature_key: "interview_prepare_access", enabled: true },
        { plan_key: "pro_monthly", feature_key: "interview_prepare_refreshes", enabled: true, limit: 10 },

        # Sprint
        { plan_key: "sprint_one_time", feature_key: "cv_parsing_basic", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "cv_parsing_full", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "skill_domain_extraction_limited", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "skill_domain_extraction_full", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "interviews", enabled: true, limit: nil },
        { plan_key: "sprint_one_time", feature_key: "ai_summaries", enabled: true, limit: 200 },
        { plan_key: "sprint_one_time", feature_key: "pattern_detection", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "cv_feedback_comparison", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "cv_feedback_comparison_enhanced", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "assistant_access", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "assistant_priority", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "background_processing_priority", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "insight_export", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "interview_prepare_access", enabled: true },
        { plan_key: "sprint_one_time", feature_key: "interview_prepare_refreshes", enabled: true, limit: 50 }
      ]
    end
  end
end
