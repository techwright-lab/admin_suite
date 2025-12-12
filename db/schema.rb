# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_11_235931) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.text "about"
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["name"], name: "index_companies_on_name", unique: true
  end

  create_table "company_feedbacks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "feedback_text"
    t.bigint "interview_application_id", null: false
    t.text "next_steps"
    t.datetime "received_at"
    t.text "rejection_reason"
    t.text "self_reflection"
    t.datetime "updated_at", null: false
    t.index ["interview_application_id"], name: "index_company_feedbacks_on_interview_application_id"
  end

  create_table "connected_accounts", force: :cascade do |t|
    t.text "access_token"
    t.datetime "auth_error_at"
    t.string "auth_error_message"
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "expires_at"
    t.datetime "last_synced_at"
    t.boolean "needs_reauth", default: false, null: false
    t.string "provider", null: false
    t.text "refresh_token"
    t.string "scopes"
    t.boolean "sync_enabled", default: true
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_connected_accounts_on_provider_and_uid", unique: true
    t.index ["user_id", "provider"], name: "index_connected_accounts_on_user_id_and_provider"
    t.index ["user_id"], name: "index_connected_accounts_on_user_id"
  end

  create_table "email_senders", force: :cascade do |t|
    t.bigint "auto_detected_company_id"
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "email", null: false
    t.integer "email_count", default: 1, null: false
    t.datetime "last_seen_at"
    t.string "name"
    t.string "sender_type"
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false
    t.index ["auto_detected_company_id"], name: "index_email_senders_on_auto_detected_company_id"
    t.index ["company_id"], name: "index_email_senders_on_company_id"
    t.index ["domain"], name: "index_email_senders_on_domain"
    t.index ["email"], name: "index_email_senders_on_email", unique: true
    t.index ["verified"], name: "index_email_senders_on_verified"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "html_scraping_logs", force: :cascade do |t|
    t.integer "cleaned_html_size"
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.string "error_type"
    t.float "extraction_rate"
    t.jsonb "field_results", default: {}
    t.integer "fields_attempted", default: 0
    t.integer "fields_extracted", default: 0
    t.integer "html_size"
    t.bigint "job_listing_id"
    t.bigint "scraping_attempt_id", null: false
    t.jsonb "selectors_tried", default: {}
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["created_at"], name: "index_html_scraping_logs_on_created_at"
    t.index ["domain", "created_at"], name: "index_html_scraping_logs_on_domain_and_created_at"
    t.index ["domain", "status"], name: "index_html_scraping_logs_on_domain_and_status"
    t.index ["domain"], name: "index_html_scraping_logs_on_domain"
    t.index ["extraction_rate"], name: "index_html_scraping_logs_on_extraction_rate"
    t.index ["job_listing_id"], name: "index_html_scraping_logs_on_job_listing_id"
    t.index ["scraping_attempt_id"], name: "index_html_scraping_logs_on_scraping_attempt_id"
    t.index ["status"], name: "index_html_scraping_logs_on_status"
  end

  create_table "interview_applications", force: :cascade do |t|
    t.text "ai_summary"
    t.datetime "applied_at", default: -> { "CURRENT_DATE" }
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_listing_id"
    t.bigint "job_role_id", null: false
    t.text "notes"
    t.string "pipeline_stage"
    t.string "slug"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid"
    t.index ["company_id"], name: "index_interview_applications_on_company_id"
    t.index ["job_listing_id"], name: "index_interview_applications_on_job_listing_id"
    t.index ["job_role_id"], name: "index_interview_applications_on_job_role_id"
    t.index ["pipeline_stage"], name: "index_interview_applications_on_pipeline_stage"
    t.index ["slug"], name: "index_interview_applications_on_slug", unique: true
    t.index ["status"], name: "index_interview_applications_on_status"
    t.index ["user_id", "created_at"], name: "index_interview_applications_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_interview_applications_on_user_id"
    t.index ["uuid"], name: "index_interview_applications_on_uuid", unique: true
  end

  create_table "interview_feedbacks", force: :cascade do |t|
    t.text "ai_summary"
    t.datetime "created_at", null: false
    t.bigint "interview_round_id", null: false
    t.text "interviewer_notes"
    t.string "recommended_action"
    t.text "self_reflection"
    t.text "tags"
    t.text "to_improve"
    t.datetime "updated_at", null: false
    t.text "went_well"
    t.index ["interview_round_id"], name: "index_interview_feedbacks_on_interview_round_id"
  end

  create_table "interview_rounds", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.bigint "interview_application_id", null: false
    t.string "interviewer_name"
    t.string "interviewer_role"
    t.text "notes"
    t.integer "position"
    t.integer "result", default: 0
    t.datetime "scheduled_at"
    t.integer "stage", default: 0, null: false
    t.string "stage_name"
    t.datetime "updated_at", null: false
    t.index ["interview_application_id", "position"], name: "idx_on_interview_application_id_position_2ffa3d90ee"
    t.index ["interview_application_id"], name: "index_interview_rounds_on_interview_application_id"
    t.index ["result"], name: "index_interview_rounds_on_result"
    t.index ["stage"], name: "index_interview_rounds_on_stage"
  end

  create_table "interview_skill_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "interview_id", null: false
    t.bigint "skill_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["interview_id", "skill_tag_id"], name: "index_interview_skill_tags_on_interview_id_and_skill_tag_id", unique: true
    t.index ["interview_id"], name: "index_interview_skill_tags_on_interview_id"
    t.index ["skill_tag_id"], name: "index_interview_skill_tags_on_skill_tag_id"
  end

  create_table "job_listings", force: :cascade do |t|
    t.text "benefits"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_sections", default: {}
    t.text "description"
    t.text "equity_info"
    t.string "job_board_id"
    t.bigint "job_role_id", null: false
    t.string "location"
    t.text "perks"
    t.integer "remote_type", default: 0
    t.text "requirements"
    t.text "responsibilities"
    t.string "salary_currency", default: "USD"
    t.decimal "salary_max", precision: 12, scale: 2
    t.decimal "salary_min", precision: 12, scale: 2
    t.jsonb "scraped_data", default: {}
    t.string "source_id"
    t.integer "status", default: 0
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["company_id", "job_role_id"], name: "index_job_listings_on_company_id_and_job_role_id"
    t.index ["company_id"], name: "index_job_listings_on_company_id"
    t.index ["job_role_id"], name: "index_job_listings_on_job_role_id"
    t.index ["remote_type"], name: "index_job_listings_on_remote_type"
    t.index ["status"], name: "index_job_listings_on_status"
  end

  create_table "job_roles", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_job_roles_on_title", unique: true
  end

  create_table "llm_api_logs", force: :cascade do |t|
    t.float "confidence_score"
    t.integer "content_size"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "error_type"
    t.integer "estimated_cost_cents"
    t.jsonb "extracted_fields", default: []
    t.integer "input_tokens"
    t.integer "latency_ms"
    t.bigint "llm_prompt_id"
    t.bigint "loggable_id"
    t.string "loggable_type"
    t.string "model", null: false
    t.string "operation_type", null: false
    t.integer "output_tokens"
    t.string "provider", null: false
    t.jsonb "request_payload", default: {}
    t.jsonb "response_payload", default: {}
    t.integer "status", default: 0, null: false
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_llm_api_logs_on_created_at"
    t.index ["llm_prompt_id"], name: "index_llm_api_logs_on_llm_prompt_id"
    t.index ["loggable_type", "loggable_id"], name: "index_llm_api_logs_on_loggable"
    t.index ["loggable_type", "loggable_id"], name: "index_llm_api_logs_on_loggable_type_and_loggable_id"
    t.index ["operation_type", "created_at"], name: "index_llm_api_logs_on_operation_type_and_created_at"
    t.index ["operation_type", "status"], name: "index_llm_api_logs_on_operation_type_and_status"
    t.index ["operation_type"], name: "index_llm_api_logs_on_operation_type"
    t.index ["provider", "created_at"], name: "index_llm_api_logs_on_provider_and_created_at"
    t.index ["provider", "status"], name: "index_llm_api_logs_on_provider_and_status"
    t.index ["provider"], name: "index_llm_api_logs_on_provider"
    t.index ["status"], name: "index_llm_api_logs_on_status"
  end

  create_table "llm_prompts", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.text "prompt_template", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.jsonb "variables", default: {}
    t.integer "version", default: 1, null: false
    t.index ["active"], name: "index_llm_prompts_on_active"
    t.index ["name"], name: "index_llm_prompts_on_name"
    t.index ["type", "active", "version"], name: "index_llm_prompts_on_type_and_active_and_version"
    t.index ["type", "active"], name: "index_llm_prompts_on_type_and_active"
    t.index ["type"], name: "index_llm_prompts_on_type"
  end

  create_table "llm_provider_configs", force: :cascade do |t|
    t.string "api_endpoint"
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "llm_model", null: false
    t.integer "max_tokens", default: 4096
    t.string "name", null: false
    t.integer "priority", default: 0, null: false
    t.string "provider_type", null: false
    t.jsonb "settings", default: {}
    t.float "temperature", default: 0.0
    t.datetime "updated_at", null: false
    t.index ["enabled", "priority"], name: "index_llm_provider_configs_on_enabled_and_priority"
    t.index ["enabled"], name: "index_llm_provider_configs_on_enabled"
    t.index ["provider_type"], name: "index_llm_provider_configs_on_provider_type"
  end

  create_table "opportunities", force: :cascade do |t|
    t.float "ai_confidence_score"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.text "email_snippet"
    t.jsonb "extracted_data", default: {}
    t.jsonb "extracted_links", default: []
    t.bigint "interview_application_id"
    t.string "job_role_title"
    t.string "job_url"
    t.text "key_details"
    t.string "recruiter_company"
    t.string "recruiter_email"
    t.string "recruiter_name"
    t.string "source_type"
    t.string "status", default: "new", null: false
    t.bigint "synced_email_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["interview_application_id"], name: "index_opportunities_on_interview_application_id"
    t.index ["source_type"], name: "index_opportunities_on_source_type"
    t.index ["status"], name: "index_opportunities_on_status"
    t.index ["synced_email_id"], name: "index_opportunities_on_synced_email_id"
    t.index ["user_id", "created_at"], name: "index_opportunities_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_opportunities_on_user_id_and_status"
    t.index ["user_id"], name: "index_opportunities_on_user_id"
  end

  create_table "resume_skills", force: :cascade do |t|
    t.string "category"
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.text "evidence_snippet"
    t.integer "model_level", null: false
    t.bigint "skill_tag_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_level"
    t.bigint "user_resume_id", null: false
    t.integer "years_of_experience"
    t.index ["category"], name: "index_resume_skills_on_category"
    t.index ["skill_tag_id"], name: "index_resume_skills_on_skill_tag_id"
    t.index ["user_resume_id", "skill_tag_id"], name: "index_resume_skills_on_user_resume_id_and_skill_tag_id", unique: true
    t.index ["user_resume_id"], name: "index_resume_skills_on_user_resume_id"
  end

  create_table "scraped_job_listing_data", force: :cascade do |t|
    t.text "cleaned_html"
    t.string "content_hash"
    t.datetime "created_at", null: false
    t.jsonb "fetch_metadata", default: {}
    t.text "html_content"
    t.integer "http_status"
    t.bigint "job_listing_id", null: false
    t.bigint "scraping_attempt_id"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.datetime "valid_until", null: false
    t.index ["content_hash"], name: "index_scraped_job_listing_data_on_content_hash"
    t.index ["job_listing_id"], name: "index_scraped_job_listing_data_on_job_listing_id"
    t.index ["scraping_attempt_id"], name: "index_scraped_job_listing_data_on_scraping_attempt_id"
    t.index ["url", "valid_until"], name: "index_scraped_job_listing_data_on_url_and_valid_until"
    t.index ["url"], name: "index_scraped_job_listing_data_on_url"
    t.index ["valid_until"], name: "index_scraped_job_listing_data_on_valid_until"
  end

  create_table "scraping_attempts", force: :cascade do |t|
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.float "duration_seconds"
    t.text "error_message"
    t.string "extraction_method"
    t.string "failed_step"
    t.integer "http_status"
    t.bigint "job_listing_id", null: false
    t.string "provider"
    t.jsonb "request_metadata", default: {}
    t.jsonb "response_metadata", default: {}
    t.integer "retry_count", default: 0
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["created_at"], name: "index_scraping_attempts_on_created_at"
    t.index ["domain", "status"], name: "index_scraping_attempts_on_domain_and_status"
    t.index ["domain"], name: "index_scraping_attempts_on_domain"
    t.index ["job_listing_id"], name: "index_scraping_attempts_on_job_listing_id"
    t.index ["status", "created_at"], name: "index_scraping_attempts_on_status_and_created_at"
    t.index ["status"], name: "index_scraping_attempts_on_status"
  end

  create_table "scraping_events", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.string "error_type"
    t.string "event_type", null: false
    t.jsonb "input_payload", default: {}
    t.bigint "job_listing_id"
    t.jsonb "metadata", default: {}
    t.jsonb "output_payload", default: {}
    t.bigint "scraping_attempt_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "step_order"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_scraping_events_on_created_at"
    t.index ["event_type"], name: "index_scraping_events_on_event_type"
    t.index ["job_listing_id"], name: "index_scraping_events_on_job_listing_id"
    t.index ["scraping_attempt_id", "event_type"], name: "index_scraping_events_on_scraping_attempt_id_and_event_type"
    t.index ["scraping_attempt_id", "step_order"], name: "index_scraping_events_on_scraping_attempt_id_and_step_order"
    t.index ["scraping_attempt_id"], name: "index_scraping_events_on_scraping_attempt_id"
    t.index ["status"], name: "index_scraping_events_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
    t.boolean "value"
  end

  create_table "skill_tags", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_skill_tags_on_name", unique: true
  end

  create_table "support_tickets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.text "message", null: false
    t.string "name", null: false
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["created_at"], name: "index_support_tickets_on_created_at"
    t.index ["email"], name: "index_support_tickets_on_email"
    t.index ["status"], name: "index_support_tickets_on_status"
    t.index ["user_id"], name: "index_support_tickets_on_user_id"
  end

  create_table "synced_emails", force: :cascade do |t|
    t.text "body_preview"
    t.bigint "connected_account_id", null: false
    t.datetime "created_at", null: false
    t.string "detected_company"
    t.datetime "email_date"
    t.bigint "email_sender_id"
    t.string "email_type"
    t.string "from_email", null: false
    t.string "from_name"
    t.string "gmail_id", null: false
    t.bigint "interview_application_id"
    t.jsonb "labels", default: []
    t.jsonb "metadata", default: {}
    t.text "snippet"
    t.integer "status", default: 0, null: false
    t.string "subject"
    t.string "thread_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["connected_account_id"], name: "index_synced_emails_on_connected_account_id"
    t.index ["email_date"], name: "index_synced_emails_on_email_date"
    t.index ["email_sender_id"], name: "index_synced_emails_on_email_sender_id"
    t.index ["email_type"], name: "index_synced_emails_on_email_type"
    t.index ["from_email"], name: "index_synced_emails_on_from_email"
    t.index ["interview_application_id"], name: "index_synced_emails_on_interview_application_id"
    t.index ["status"], name: "index_synced_emails_on_status"
    t.index ["thread_id"], name: "index_synced_emails_on_thread_id"
    t.index ["user_id", "gmail_id"], name: "index_synced_emails_on_user_id_and_gmail_id", unique: true
    t.index ["user_id"], name: "index_synced_emails_on_user_id"
  end

  create_table "transitions", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.string "event"
    t.string "from_state"
    t.bigint "resource_id", null: false
    t.string "resource_type", null: false
    t.string "to_state"
    t.datetime "updated_at", null: false
    t.index ["resource_type", "resource_id"], name: "index_transitions_on_resource"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.boolean "ai_feedback_analysis", default: true
    t.string "ai_insights_frequency", default: "weekly"
    t.boolean "ai_interview_prep", default: true
    t.boolean "ai_summary_enabled", default: true
    t.datetime "created_at", null: false
    t.integer "data_retention_days", default: 0
    t.boolean "email_interview_reminders", default: true
    t.boolean "email_notifications", default: true
    t.boolean "email_weekly_digest", default: true
    t.string "preferred_view", default: "kanban"
    t.string "theme", default: "system"
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "user_resume_target_companies", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_resume_id", null: false
    t.index ["company_id"], name: "index_user_resume_target_companies_on_company_id"
    t.index ["user_resume_id", "company_id"], name: "idx_resume_target_companies_unique", unique: true
    t.index ["user_resume_id"], name: "index_user_resume_target_companies_on_user_resume_id"
  end

  create_table "user_resume_target_job_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_resume_id", null: false
    t.index ["job_role_id"], name: "index_user_resume_target_job_roles_on_job_role_id"
    t.index ["user_resume_id", "job_role_id"], name: "idx_resume_target_roles_unique", unique: true
    t.index ["user_resume_id"], name: "index_user_resume_target_job_roles_on_user_resume_id"
  end

  create_table "user_resumes", force: :cascade do |t|
    t.integer "analysis_status", default: 0, null: false
    t.text "analysis_summary"
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.jsonb "extracted_data", default: {}
    t.string "name", null: false
    t.text "parsed_text"
    t.integer "purpose", default: 0, null: false
    t.string "resume_date_confidence"
    t.string "resume_date_source"
    t.date "resume_updated_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["analysis_status"], name: "index_user_resumes_on_analysis_status"
    t.index ["user_id", "created_at"], name: "index_user_resumes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_resumes_on_user_id"
  end

  create_table "user_skills", force: :cascade do |t|
    t.float "aggregated_level", null: false
    t.string "category"
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.datetime "last_demonstrated_at"
    t.integer "max_years_experience"
    t.integer "resume_count", default: 0
    t.bigint "skill_tag_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["skill_tag_id"], name: "index_user_skills_on_skill_tag_id"
    t.index ["user_id", "aggregated_level"], name: "index_user_skills_on_user_id_and_aggregated_level"
    t.index ["user_id", "category"], name: "index_user_skills_on_user_id_and_category"
    t.index ["user_id", "skill_tag_id"], name: "index_user_skills_on_user_id_and_skill_tag_id", unique: true
    t.index ["user_id"], name: "index_user_skills_on_user_id"
  end

  create_table "user_target_companies", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "priority"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_user_target_companies_on_company_id"
    t.index ["user_id", "company_id"], name: "index_user_target_companies_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_user_target_companies_on_user_id"
  end

  create_table "user_target_job_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_role_id", null: false
    t.integer "priority"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["job_role_id"], name: "index_user_target_job_roles_on_job_role_id"
    t.index ["user_id", "job_role_id"], name: "index_user_target_job_roles_on_user_id_and_job_role_id", unique: true
    t.index ["user_id"], name: "index_user_target_job_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.bigint "current_company_id"
    t.bigint "current_job_role_id"
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.string "github_url"
    t.string "gitlab_url"
    t.boolean "is_admin", default: false, null: false
    t.string "linkedin_url"
    t.string "name"
    t.string "oauth_provider"
    t.string "oauth_uid"
    t.string "password_digest", null: false
    t.string "portfolio_url"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.integer "years_of_experience"
    t.index ["current_company_id"], name: "index_users_on_current_company_id"
    t.index ["current_job_role_id"], name: "index_users_on_current_job_role_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["oauth_provider", "oauth_uid"], name: "index_users_on_oauth_provider_and_oauth_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "company_feedbacks", "interview_applications"
  add_foreign_key "connected_accounts", "users"
  add_foreign_key "email_senders", "companies"
  add_foreign_key "email_senders", "companies", column: "auto_detected_company_id"
  add_foreign_key "html_scraping_logs", "job_listings"
  add_foreign_key "html_scraping_logs", "scraping_attempts"
  add_foreign_key "interview_applications", "companies"
  add_foreign_key "interview_applications", "job_listings"
  add_foreign_key "interview_applications", "job_roles"
  add_foreign_key "interview_applications", "users"
  add_foreign_key "interview_feedbacks", "interview_applications", column: "interview_round_id"
  add_foreign_key "interview_rounds", "interview_applications"
  add_foreign_key "interview_skill_tags", "interview_applications", column: "interview_id"
  add_foreign_key "interview_skill_tags", "skill_tags"
  add_foreign_key "job_listings", "companies"
  add_foreign_key "job_listings", "job_roles"
  add_foreign_key "llm_api_logs", "llm_prompts"
  add_foreign_key "opportunities", "interview_applications"
  add_foreign_key "opportunities", "synced_emails"
  add_foreign_key "opportunities", "users"
  add_foreign_key "resume_skills", "skill_tags"
  add_foreign_key "resume_skills", "user_resumes"
  add_foreign_key "scraped_job_listing_data", "job_listings"
  add_foreign_key "scraped_job_listing_data", "scraping_attempts"
  add_foreign_key "scraping_attempts", "job_listings"
  add_foreign_key "scraping_events", "job_listings"
  add_foreign_key "scraping_events", "scraping_attempts"
  add_foreign_key "sessions", "users"
  add_foreign_key "support_tickets", "users"
  add_foreign_key "synced_emails", "connected_accounts"
  add_foreign_key "synced_emails", "email_senders"
  add_foreign_key "synced_emails", "interview_applications"
  add_foreign_key "synced_emails", "users"
  add_foreign_key "user_preferences", "users"
  add_foreign_key "user_resume_target_companies", "companies"
  add_foreign_key "user_resume_target_companies", "user_resumes"
  add_foreign_key "user_resume_target_job_roles", "job_roles"
  add_foreign_key "user_resume_target_job_roles", "user_resumes"
  add_foreign_key "user_resumes", "users"
  add_foreign_key "user_skills", "skill_tags"
  add_foreign_key "user_skills", "users"
  add_foreign_key "user_target_companies", "companies"
  add_foreign_key "user_target_companies", "users"
  add_foreign_key "user_target_job_roles", "job_roles"
  add_foreign_key "user_target_job_roles", "users"
  add_foreign_key "users", "companies", column: "current_company_id"
  add_foreign_key "users", "job_roles", column: "current_job_role_id"
end
