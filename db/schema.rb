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

ActiveRecord::Schema[8.1].define(version: 2026_01_25_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "assistant_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "severity", default: "info", null: false
    t.bigint "thread_id", null: false
    t.string "trace_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["event_type", "created_at"], name: "index_assistant_events_on_event_type_and_created_at"
    t.index ["thread_id", "created_at"], name: "index_assistant_events_on_thread_id_and_created_at"
    t.index ["thread_id"], name: "index_assistant_events_on_thread_id"
    t.index ["trace_id"], name: "index_assistant_events_on_trace_id"
    t.index ["uuid"], name: "index_assistant_events_on_uuid", unique: true
  end

  create_table "assistant_memory_proposals", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.bigint "confirmed_by_id"
    t.datetime "created_at", null: false
    t.bigint "llm_api_log_id"
    t.jsonb "proposed_items", default: [], null: false
    t.string "status", default: "pending", null: false
    t.bigint "thread_id", null: false
    t.string "trace_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["confirmed_by_id"], name: "index_assistant_memory_proposals_on_confirmed_by_id"
    t.index ["llm_api_log_id"], name: "index_assistant_memory_proposals_on_llm_api_log_id"
    t.index ["thread_id"], name: "index_assistant_memory_proposals_on_thread_id"
    t.index ["trace_id"], name: "index_assistant_memory_proposals_on_trace_id"
    t.index ["user_id", "status"], name: "index_assistant_memory_proposals_on_user_id_and_status"
    t.index ["user_id"], name: "index_assistant_memory_proposals_on_user_id"
    t.index ["uuid"], name: "index_assistant_memory_proposals_on_uuid", unique: true
  end

  create_table "assistant_messages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "role", null: false
    t.bigint "thread_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["thread_id", "created_at"], name: "index_assistant_messages_on_thread_id_and_created_at"
    t.index ["thread_id"], name: "index_assistant_messages_on_thread_id"
    t.index ["uuid"], name: "index_assistant_messages_on_uuid", unique: true
  end

  create_table "assistant_thread_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "last_summarized_message_id"
    t.bigint "llm_api_log_id"
    t.text "summary_text", default: "", null: false
    t.integer "summary_version", default: 1, null: false
    t.bigint "thread_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["last_summarized_message_id"], name: "index_assistant_thread_summaries_on_last_summarized_message_id"
    t.index ["llm_api_log_id"], name: "index_assistant_thread_summaries_on_llm_api_log_id"
    t.index ["thread_id"], name: "index_assistant_thread_summaries_on_thread_id", unique: true
    t.index ["uuid"], name: "index_assistant_thread_summaries_on_uuid", unique: true
  end

  create_table "assistant_threads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_activity_at"
    t.string "status", default: "open", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["user_id", "last_activity_at"], name: "index_assistant_threads_on_user_id_and_last_activity_at"
    t.index ["user_id"], name: "index_assistant_threads_on_user_id"
    t.index ["uuid"], name: "index_assistant_threads_on_uuid", unique: true
  end

  create_table "assistant_tool_executions", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.jsonb "args", default: {}, null: false
    t.bigint "assistant_message_id", null: false
    t.datetime "created_at", null: false
    t.text "error"
    t.datetime "finished_at"
    t.string "idempotency_key"
    t.jsonb "metadata", default: {}, null: false
    t.string "provider_name"
    t.string "provider_tool_call_id"
    t.bigint "replay_of_id"
    t.uuid "replay_request_uuid"
    t.boolean "requires_confirmation", default: false, null: false
    t.jsonb "result", default: {}, null: false
    t.datetime "started_at"
    t.string "status", default: "proposed", null: false
    t.bigint "thread_id", null: false
    t.string "tool_key", null: false
    t.string "trace_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["approved_by_id"], name: "index_assistant_tool_executions_on_approved_by_id"
    t.index ["assistant_message_id"], name: "index_assistant_tool_executions_on_assistant_message_id"
    t.index ["metadata"], name: "index_assistant_tool_executions_on_metadata", using: :gin
    t.index ["provider_name"], name: "index_assistant_tool_executions_on_provider_name"
    t.index ["provider_tool_call_id"], name: "index_assistant_tool_executions_on_provider_tool_call_id"
    t.index ["replay_of_id", "replay_request_uuid"], name: "idx_assistant_tool_executions_replay_idempotency", unique: true, where: "((replay_of_id IS NOT NULL) AND (replay_request_uuid IS NOT NULL))"
    t.index ["replay_of_id"], name: "index_assistant_tool_executions_on_replay_of_id"
    t.index ["thread_id", "idempotency_key"], name: "idx_on_thread_id_idempotency_key_3a3fdc6f78", unique: true
    t.index ["thread_id"], name: "index_assistant_tool_executions_on_thread_id"
    t.index ["trace_id"], name: "index_assistant_tool_executions_on_trace_id"
    t.index ["uuid"], name: "index_assistant_tool_executions_on_uuid", unique: true
  end

  create_table "assistant_tools", force: :cascade do |t|
    t.jsonb "arg_schema", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.boolean "enabled", default: true, null: false
    t.string "executor_class", null: false
    t.string "name", null: false
    t.jsonb "rate_limit", default: {}, null: false
    t.boolean "requires_confirmation", default: false, null: false
    t.string "risk_level", default: "read_only", null: false
    t.integer "timeout_ms", default: 5000, null: false
    t.string "tool_key", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_assistant_tools_on_enabled"
    t.index ["tool_key"], name: "index_assistant_tools_on_tool_key", unique: true
  end

  create_table "assistant_turns", force: :cascade do |t|
    t.bigint "assistant_message_id", null: false
    t.uuid "client_request_uuid"
    t.jsonb "context_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "latency_ms"
    t.bigint "llm_api_log_id", null: false
    t.string "provider_name"
    t.jsonb "provider_state", default: {}, null: false
    t.string "status", default: "success", null: false
    t.bigint "thread_id", null: false
    t.string "trace_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_message_id", null: false
    t.uuid "uuid", null: false
    t.index ["assistant_message_id"], name: "index_assistant_turns_on_assistant_message_id"
    t.index ["llm_api_log_id"], name: "index_assistant_turns_on_llm_api_log_id"
    t.index ["provider_name"], name: "index_assistant_turns_on_provider_name"
    t.index ["thread_id", "client_request_uuid"], name: "idx_assistant_turns_thread_client_request_uuid", unique: true, where: "(client_request_uuid IS NOT NULL)"
    t.index ["thread_id"], name: "index_assistant_turns_on_thread_id"
    t.index ["trace_id"], name: "index_assistant_turns_on_trace_id"
    t.index ["user_message_id"], name: "index_assistant_turns_on_user_message_id"
    t.index ["uuid"], name: "index_assistant_turns_on_uuid", unique: true
  end

  create_table "assistant_user_memories", force: :cascade do |t|
    t.float "confidence", default: 1.0, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "key", null: false
    t.datetime "last_confirmed_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "source", default: "user", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.jsonb "value", default: {}, null: false
    t.index ["expires_at"], name: "index_assistant_user_memories_on_expires_at"
    t.index ["user_id", "key"], name: "index_assistant_user_memories_on_user_id_and_key", unique: true
    t.index ["user_id"], name: "index_assistant_user_memories_on_user_id"
    t.index ["uuid"], name: "index_assistant_user_memories_on_uuid", unique: true
  end

  create_table "billing_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_customer_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.jsonb "urls", default: {}, null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["provider", "external_customer_id"], name: "index_billing_customers_on_provider_and_external_customer_id", unique: true
    t.index ["provider", "user_id"], name: "index_billing_customers_on_provider_and_user_id", unique: true
    t.index ["user_id"], name: "index_billing_customers_on_user_id"
    t.index ["uuid"], name: "index_billing_customers_on_uuid", unique: true
  end

  create_table "billing_entitlement_grants", force: :cascade do |t|
    t.bigint "billing_plan_id"
    t.datetime "created_at", null: false
    t.jsonb "entitlements", default: {}, null: false
    t.datetime "expires_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "reason"
    t.string "source", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["billing_plan_id"], name: "index_billing_entitlement_grants_on_billing_plan_id"
    t.index ["user_id", "source", "reason"], name: "idx_on_user_id_source_reason_078dd5f8d4"
    t.index ["user_id", "starts_at", "expires_at"], name: "idx_on_user_id_starts_at_expires_at_9816456602"
    t.index ["user_id"], name: "index_billing_entitlement_grants_on_user_id"
    t.index ["uuid"], name: "index_billing_entitlement_grants_on_uuid", unique: true
  end

  create_table "billing_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["key"], name: "index_billing_features_on_key", unique: true
    t.index ["uuid"], name: "index_billing_features_on_uuid", unique: true
  end

  create_table "billing_orders", force: :cascade do |t|
    t.bigint "billing_customer_id"
    t.bigint "billing_subscription_id"
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "external_order_id", null: false
    t.string "identifier"
    t.jsonb "metadata", default: {}, null: false
    t.string "order_number"
    t.string "provider", null: false
    t.string "receipt_url"
    t.string "status"
    t.integer "total_cents"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["billing_customer_id"], name: "index_billing_orders_on_billing_customer_id"
    t.index ["billing_subscription_id"], name: "index_billing_orders_on_billing_subscription_id"
    t.index ["provider", "external_order_id"], name: "index_billing_orders_on_provider_and_external_order_id", unique: true
    t.index ["provider", "user_id"], name: "index_billing_orders_on_provider_and_user_id"
    t.index ["user_id"], name: "index_billing_orders_on_user_id"
    t.index ["uuid"], name: "index_billing_orders_on_uuid", unique: true
  end

  create_table "billing_plan_entitlements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "feature_id", null: false
    t.integer "limit"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_id"], name: "index_billing_plan_entitlements_on_feature_id"
    t.index ["plan_id", "feature_id"], name: "index_billing_plan_entitlements_on_plan_and_feature", unique: true
    t.index ["plan_id"], name: "index_billing_plan_entitlements_on_plan_id"
  end

  create_table "billing_plans", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.string "currency", default: "eur", null: false
    t.text "description"
    t.boolean "highlighted", default: false, null: false
    t.string "interval"
    t.string "key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.string "plan_type", null: false
    t.boolean "published", default: false, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["key"], name: "index_billing_plans_on_key", unique: true
    t.index ["published", "sort_order"], name: "index_billing_plans_on_published_and_sort_order"
    t.index ["published"], name: "index_billing_plans_on_published"
    t.index ["uuid"], name: "index_billing_plans_on_uuid", unique: true
  end

  create_table "billing_provider_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_price_id"
    t.string "external_product_id"
    t.string "external_variant_id"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "plan_id", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["plan_id"], name: "index_billing_provider_mappings_on_plan_id"
    t.index ["provider", "plan_id"], name: "index_billing_provider_mappings_on_provider_and_plan", unique: true
    t.index ["uuid"], name: "index_billing_provider_mappings_on_uuid", unique: true
  end

  create_table "billing_subscriptions", force: :cascade do |t|
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "cancelled_at"
    t.string "card_brand"
    t.string "card_last_four"
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.datetime "current_period_starts_at"
    t.string "external_subscription_id"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "plan_id"
    t.string "provider", null: false
    t.string "status", default: "inactive", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.jsonb "urls", default: {}, null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["current_period_ends_at"], name: "index_billing_subscriptions_on_current_period_ends_at"
    t.index ["plan_id"], name: "index_billing_subscriptions_on_plan_id"
    t.index ["provider", "external_subscription_id"], name: "idx_on_provider_external_subscription_id_d2b106a251", unique: true
    t.index ["provider", "user_id"], name: "index_billing_subscriptions_on_provider_and_user_id"
    t.index ["user_id", "status"], name: "index_billing_subscriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_billing_subscriptions_on_user_id"
    t.index ["uuid"], name: "index_billing_subscriptions_on_uuid", unique: true
  end

  create_table "billing_usage_counters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "period_ends_at", null: false
    t.datetime "period_starts_at", null: false
    t.datetime "updated_at", null: false
    t.integer "used", default: 0, null: false
    t.bigint "user_id", null: false
    t.uuid "uuid", null: false
    t.index ["user_id", "feature_key", "period_starts_at"], name: "index_billing_usage_counters_on_user_feature_period", unique: true
    t.index ["user_id", "feature_key"], name: "index_billing_usage_counters_on_user_id_and_feature_key"
    t.index ["user_id"], name: "index_billing_usage_counters_on_user_id"
    t.index ["uuid"], name: "index_billing_usage_counters_on_uuid", unique: true
  end

  create_table "billing_webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_type"
    t.string "idempotency_key", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.string "provider", null: false
    t.datetime "received_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", null: false
    t.index ["provider", "event_type", "received_at"], name: "idx_on_provider_event_type_received_at_2f0a9d15ed"
    t.index ["provider", "idempotency_key"], name: "index_billing_webhook_events_on_provider_and_idempotency_key", unique: true
    t.index ["provider", "status", "received_at"], name: "idx_on_provider_status_received_at_ef483882cf"
    t.index ["uuid"], name: "index_billing_webhook_events_on_uuid", unique: true
  end

  create_table "blog_posts", force: :cascade do |t|
    t.string "author_name"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.datetime "published_at"
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.string "tags"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_blog_posts_on_published_at"
    t.index ["slug"], name: "index_blog_posts_on_slug", unique: true
    t.index ["status"], name: "index_blog_posts_on_status"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.integer "kind", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text), kind", name: "index_categories_on_lower_name_and_kind", unique: true
    t.index ["disabled_at"], name: "index_categories_on_disabled_at"
    t.index ["kind"], name: "index_categories_on_kind"
  end

  create_table "companies", force: :cascade do |t|
    t.text "about"
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "logo_url"
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["disabled_at"], name: "index_companies_on_disabled_at"
    t.index ["name"], name: "index_companies_on_name", unique: true
  end

  create_table "company_feedbacks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "feedback_text"
    t.string "feedback_type"
    t.bigint "interview_application_id", null: false
    t.text "next_steps"
    t.datetime "received_at"
    t.text "rejection_reason"
    t.text "self_reflection"
    t.bigint "source_email_id"
    t.datetime "updated_at", null: false
    t.index ["interview_application_id"], name: "index_company_feedbacks_on_interview_application_id"
    t.index ["source_email_id"], name: "index_company_feedbacks_on_source_email_id"
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

  create_table "developers", force: :cascade do |t|
    t.text "access_token"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "last_login_at"
    t.string "last_login_ip"
    t.integer "login_count", default: 0
    t.string "name"
    t.text "refresh_token"
    t.string "techwright_uid", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_developers_on_email"
    t.index ["enabled"], name: "index_developers_on_enabled"
    t.index ["techwright_uid"], name: "index_developers_on_techwright_uid", unique: true
  end

  create_table "domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "disabled_at"
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["disabled_at"], name: "index_domains_on_disabled_at"
    t.index ["name"], name: "index_domains_on_name", unique: true
    t.index ["slug"], name: "index_domains_on_slug", unique: true
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

  create_table "fit_assessments", force: :cascade do |t|
    t.string "algorithm_version"
    t.jsonb "breakdown", default: {}, null: false
    t.datetime "computed_at"
    t.datetime "created_at", null: false
    t.bigint "fittable_id", null: false
    t.string "fittable_type", null: false
    t.string "inputs_digest"
    t.integer "score"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["computed_at"], name: "index_fit_assessments_on_computed_at"
    t.index ["fittable_type", "fittable_id"], name: "index_fit_assessments_on_fittable"
    t.index ["user_id", "fittable_type", "fittable_id"], name: "index_fit_assessments_on_user_and_fittable_unique", unique: true
    t.index ["user_id"], name: "index_fit_assessments_on_user_id"
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
    t.string "board_type"
    t.integer "cleaned_html_size"
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.string "error_type"
    t.float "extraction_rate"
    t.string "extractor_kind"
    t.string "fetch_mode"
    t.jsonb "field_results", default: {}
    t.integer "fields_attempted", default: 0
    t.integer "fields_extracted", default: 0
    t.integer "html_size"
    t.bigint "job_listing_id"
    t.string "run_context"
    t.bigint "scraping_attempt_id", null: false
    t.jsonb "selectors_tried", default: {}
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["board_type"], name: "index_html_scraping_logs_on_board_type"
    t.index ["created_at"], name: "index_html_scraping_logs_on_created_at"
    t.index ["domain", "created_at"], name: "index_html_scraping_logs_on_domain_and_created_at"
    t.index ["domain", "status"], name: "index_html_scraping_logs_on_domain_and_status"
    t.index ["domain"], name: "index_html_scraping_logs_on_domain"
    t.index ["extraction_rate"], name: "index_html_scraping_logs_on_extraction_rate"
    t.index ["extractor_kind"], name: "index_html_scraping_logs_on_extractor_kind"
    t.index ["fetch_mode"], name: "index_html_scraping_logs_on_fetch_mode"
    t.index ["job_listing_id"], name: "index_html_scraping_logs_on_job_listing_id"
    t.index ["run_context"], name: "index_html_scraping_logs_on_run_context"
    t.index ["scraping_attempt_id"], name: "index_html_scraping_logs_on_scraping_attempt_id"
    t.index ["status"], name: "index_html_scraping_logs_on_status"
  end

  create_table "interview_applications", force: :cascade do |t|
    t.text "ai_summary"
    t.datetime "applied_at", default: -> { "CURRENT_DATE" }
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "job_description_text"
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
    t.index ["deleted_at"], name: "index_interview_applications_on_deleted_at"
    t.index ["job_listing_id"], name: "index_interview_applications_on_job_listing_id"
    t.index ["job_role_id"], name: "index_interview_applications_on_job_role_id"
    t.index ["pipeline_stage"], name: "index_interview_applications_on_pipeline_stage"
    t.index ["slug"], name: "index_interview_applications_on_slug", unique: true
    t.index ["status"], name: "index_interview_applications_on_status"
    t.index ["user_id", "created_at"], name: "index_interview_applications_on_user_id_and_created_at"
    t.index ["user_id", "deleted_at"], name: "index_interview_applications_on_user_id_and_deleted_at"
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

  create_table "interview_prep_artifacts", force: :cascade do |t|
    t.datetime "computed_at"
    t.jsonb "content", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.string "inputs_digest", null: false
    t.bigint "interview_application_id", null: false
    t.integer "kind", null: false
    t.bigint "llm_api_log_id"
    t.string "model"
    t.string "provider"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid", null: false
    t.index ["inputs_digest"], name: "index_interview_prep_artifacts_on_inputs_digest"
    t.index ["interview_application_id", "kind"], name: "idx_prep_artifacts_on_app_and_kind", unique: true
    t.index ["interview_application_id"], name: "index_interview_prep_artifacts_on_interview_application_id"
    t.index ["llm_api_log_id"], name: "index_interview_prep_artifacts_on_llm_api_log_id"
    t.index ["status"], name: "index_interview_prep_artifacts_on_status"
    t.index ["user_id", "kind"], name: "idx_prep_artifacts_on_user_and_kind"
    t.index ["user_id"], name: "index_interview_prep_artifacts_on_user_id"
    t.index ["uuid"], name: "index_interview_prep_artifacts_on_uuid", unique: true
  end

  create_table "interview_round_prep_artifacts", force: :cascade do |t|
    t.jsonb "content", default: {}
    t.datetime "created_at", null: false
    t.datetime "generated_at"
    t.string "inputs_digest"
    t.bigint "interview_round_id", null: false
    t.string "kind", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["inputs_digest"], name: "index_interview_round_prep_artifacts_on_inputs_digest"
    t.index ["interview_round_id", "kind"], name: "idx_round_prep_artifacts_unique", unique: true
    t.index ["interview_round_id"], name: "index_interview_round_prep_artifacts_on_interview_round_id"
  end

  create_table "interview_round_types", force: :cascade do |t|
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "disabled_at"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "position"], name: "index_interview_round_types_on_category_id_and_position"
    t.index ["category_id"], name: "index_interview_round_types_on_category_id"
    t.index ["slug"], name: "index_interview_round_types_on_slug", unique: true
  end

  create_table "interview_rounds", force: :cascade do |t|
    t.datetime "completed_at"
    t.string "confirmation_source"
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.bigint "interview_application_id", null: false
    t.bigint "interview_round_type_id"
    t.string "interviewer_name"
    t.string "interviewer_role"
    t.text "notes"
    t.integer "position"
    t.integer "result", default: 0
    t.datetime "scheduled_at"
    t.bigint "source_email_id"
    t.integer "stage", default: 0, null: false
    t.string "stage_name"
    t.datetime "updated_at", null: false
    t.string "video_link"
    t.index ["interview_application_id", "position"], name: "idx_on_interview_application_id_position_2ffa3d90ee"
    t.index ["interview_application_id"], name: "index_interview_rounds_on_interview_application_id"
    t.index ["interview_round_type_id"], name: "index_interview_rounds_on_interview_round_type_id"
    t.index ["result"], name: "index_interview_rounds_on_result"
    t.index ["source_email_id"], name: "index_interview_rounds_on_source_email_id"
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
    t.text "about_company"
    t.text "benefits"
    t.text "company_culture"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "custom_sections", default: {}
    t.text "description"
    t.datetime "disabled_at"
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
    t.index ["disabled_at"], name: "index_job_listings_on_disabled_at"
    t.index ["job_role_id"], name: "index_job_listings_on_job_role_id"
    t.index ["remote_type"], name: "index_job_listings_on_remote_type"
    t.index ["status"], name: "index_job_listings_on_status"
  end

  create_table "job_roles", force: :cascade do |t|
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "disabled_at"
    t.string "legacy_category"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_job_roles_on_category_id"
    t.index ["disabled_at"], name: "index_job_roles_on_disabled_at"
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
    t.text "system_prompt"
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

  create_table "mailkick_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "list"
    t.bigint "subscriber_id"
    t.string "subscriber_type"
    t.datetime "updated_at", null: false
    t.index ["subscriber_type", "subscriber_id", "list"], name: "index_mailkick_subscriptions_on_subscriber_and_list", unique: true
  end

  create_table "newsletter_subscribers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_newsletter_subscribers_on_email", unique: true
  end

  create_table "opportunities", force: :cascade do |t|
    t.float "ai_confidence_score"
    t.datetime "archived_at"
    t.string "archived_reason"
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

  create_table "resume_work_experience_skills", force: :cascade do |t|
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.text "evidence_snippet"
    t.bigint "resume_work_experience_id", null: false
    t.bigint "skill_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_work_experience_id", "skill_tag_id"], name: "idx_rwes_unique", unique: true
    t.index ["resume_work_experience_id"], name: "idx_rwes_on_rwe_id"
    t.index ["skill_tag_id"], name: "index_resume_work_experience_skills_on_skill_tag_id"
  end

  create_table "resume_work_experiences", force: :cascade do |t|
    t.bigint "company_id"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.string "duration_text"
    t.date "end_date"
    t.jsonb "highlights", default: [], null: false
    t.bigint "job_role_id"
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "responsibilities", default: [], null: false
    t.string "role_title"
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.bigint "user_resume_id", null: false
    t.index ["company_id"], name: "index_resume_work_experiences_on_company_id"
    t.index ["company_name", "role_title"], name: "idx_resume_work_experiences_company_role"
    t.index ["job_role_id"], name: "index_resume_work_experiences_on_job_role_id"
    t.index ["user_resume_id", "start_date", "end_date"], name: "idx_resume_work_experiences_by_dates"
    t.index ["user_resume_id"], name: "index_resume_work_experiences_on_user_resume_id"
  end

  create_table "saved_jobs", force: :cascade do |t|
    t.datetime "archived_at"
    t.string "archived_reason"
    t.string "company_name"
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.string "job_role_title"
    t.text "notes"
    t.bigint "opportunity_id"
    t.string "status", default: "active", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["archived_at"], name: "index_saved_jobs_on_archived_at"
    t.index ["converted_at"], name: "index_saved_jobs_on_converted_at"
    t.index ["opportunity_id"], name: "index_saved_jobs_on_opportunity_id"
    t.index ["status"], name: "index_saved_jobs_on_status"
    t.index ["user_id", "created_at"], name: "index_saved_jobs_on_user_id_and_created_at"
    t.index ["user_id", "opportunity_id"], name: "index_saved_jobs_on_user_and_opportunity_unique", unique: true, where: "((opportunity_id IS NOT NULL) AND ((status)::text = 'active'::text))"
    t.index ["user_id", "url"], name: "index_saved_jobs_on_user_and_url_unique", unique: true, where: "((url IS NOT NULL) AND ((status)::text = 'active'::text))"
    t.index ["user_id"], name: "index_saved_jobs_on_user_id"
    t.check_constraint "(opportunity_id IS NOT NULL) <> (url IS NOT NULL)", name: "chk_saved_jobs_exactly_one_source"
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
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "legacy_category"
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_skill_tags_on_category_id"
    t.index ["disabled_at"], name: "index_skill_tags_on_disabled_at"
    t.index ["name"], name: "index_skill_tags_on_name", unique: true
    t.index ["slug"], name: "index_skill_tags_on_slug", unique: true
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
    t.text "body_html", comment: "Full HTML content of the email"
    t.text "body_preview"
    t.bigint "connected_account_id", null: false
    t.datetime "created_at", null: false
    t.string "detected_company"
    t.datetime "email_date"
    t.bigint "email_sender_id"
    t.string "email_type"
    t.datetime "extracted_at"
    t.jsonb "extracted_data", default: {}, null: false
    t.decimal "extraction_confidence", precision: 3, scale: 2
    t.string "extraction_status", default: "pending"
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
    t.index ["extraction_status"], name: "index_synced_emails_on_extraction_status"
    t.index ["from_email"], name: "index_synced_emails_on_from_email"
    t.index ["interview_application_id"], name: "index_synced_emails_on_interview_application_id"
    t.index ["status"], name: "index_synced_emails_on_status"
    t.index ["thread_id"], name: "index_synced_emails_on_thread_id"
    t.index ["user_id", "gmail_id"], name: "index_synced_emails_on_user_id_and_gmail_id", unique: true
    t.index ["user_id"], name: "index_synced_emails_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.bigint "tag_id"
    t.bigint "taggable_id"
    t.string "taggable_type"
    t.bigint "tagger_id"
    t.string "tagger_type"
    t.string "tenant", limit: 128
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tagger_type", "tagger_id"], name: "index_taggings_on_tagger_type_and_tagger_id"
    t.index ["tenant"], name: "index_taggings_on_tenant"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "taggings_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
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
    t.jsonb "domains", default: [], null: false
    t.jsonb "extracted_data", default: {}
    t.string "name", null: false
    t.text "parsed_text"
    t.integer "purpose", default: 0, null: false
    t.string "resume_date_confidence"
    t.string "resume_date_source"
    t.date "resume_updated_at"
    t.string "slug"
    t.jsonb "strengths", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["analysis_status"], name: "index_user_resumes_on_analysis_status"
    t.index ["slug"], name: "index_user_resumes_on_slug", unique: true
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

  create_table "user_target_domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_id", null: false
    t.integer "priority"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["domain_id"], name: "index_user_target_domains_on_domain_id"
    t.index ["user_id", "domain_id"], name: "idx_user_target_domains_unique", unique: true
    t.index ["user_id"], name: "index_user_target_domains_on_user_id"
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

  create_table "user_work_experience_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "last_used_on"
    t.bigint "skill_tag_id", null: false
    t.integer "source_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_work_experience_id", null: false
    t.index ["skill_tag_id"], name: "index_user_work_experience_skills_on_skill_tag_id"
    t.index ["user_work_experience_id", "skill_tag_id"], name: "idx_uwesk_unique", unique: true
    t.index ["user_work_experience_id"], name: "idx_uwesk_on_uwe_id"
  end

  create_table "user_work_experience_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "resume_work_experience_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_work_experience_id", null: false
    t.index ["resume_work_experience_id"], name: "idx_uwes_on_rwe_id"
    t.index ["user_work_experience_id", "resume_work_experience_id"], name: "idx_uwes_unique", unique: true
    t.index ["user_work_experience_id"], name: "idx_uwes_on_uwe_id"
  end

  create_table "user_work_experiences", force: :cascade do |t|
    t.bigint "company_id"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.date "end_date"
    t.jsonb "highlights", default: [], null: false
    t.bigint "job_role_id"
    t.jsonb "merge_keys", default: {}, null: false
    t.jsonb "responsibilities", default: [], null: false
    t.string "role_title"
    t.integer "source_count", default: 0, null: false
    t.integer "source_type", default: 0, null: false
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_user_work_experiences_on_company_id"
    t.index ["job_role_id"], name: "index_user_work_experiences_on_job_role_id"
    t.index ["source_type"], name: "index_user_work_experiences_on_source_type"
    t.index ["user_id", "company_name", "role_title"], name: "idx_user_work_experiences_user_company_role"
    t.index ["user_id", "start_date", "end_date"], name: "idx_user_work_experiences_user_dates"
    t.index ["user_id"], name: "index_user_work_experiences_on_user_id"
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
    t.boolean "marketing_opt_in", default: false, null: false
    t.string "name"
    t.string "oauth_provider"
    t.string "oauth_uid"
    t.string "password_digest", null: false
    t.string "portfolio_url"
    t.string "slug"
    t.datetime "terms_accepted_at"
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.integer "years_of_experience"
    t.index ["current_company_id"], name: "index_users_on_current_company_id"
    t.index ["current_job_role_id"], name: "index_users_on_current_job_role_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["oauth_provider", "oauth_uid"], name: "index_users_on_oauth_provider_and_oauth_uid", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assistant_events", "assistant_threads", column: "thread_id"
  add_foreign_key "assistant_memory_proposals", "assistant_threads", column: "thread_id"
  add_foreign_key "assistant_memory_proposals", "llm_api_logs"
  add_foreign_key "assistant_memory_proposals", "users"
  add_foreign_key "assistant_memory_proposals", "users", column: "confirmed_by_id"
  add_foreign_key "assistant_messages", "assistant_threads", column: "thread_id"
  add_foreign_key "assistant_thread_summaries", "assistant_messages", column: "last_summarized_message_id"
  add_foreign_key "assistant_thread_summaries", "assistant_threads", column: "thread_id"
  add_foreign_key "assistant_thread_summaries", "llm_api_logs"
  add_foreign_key "assistant_threads", "users"
  add_foreign_key "assistant_tool_executions", "assistant_messages"
  add_foreign_key "assistant_tool_executions", "assistant_threads", column: "thread_id"
  add_foreign_key "assistant_tool_executions", "users", column: "approved_by_id"
  add_foreign_key "assistant_turns", "assistant_messages"
  add_foreign_key "assistant_turns", "assistant_messages", column: "user_message_id"
  add_foreign_key "assistant_turns", "assistant_threads", column: "thread_id"
  add_foreign_key "assistant_turns", "llm_api_logs"
  add_foreign_key "assistant_user_memories", "users"
  add_foreign_key "billing_customers", "users"
  add_foreign_key "billing_entitlement_grants", "billing_plans", on_delete: :nullify
  add_foreign_key "billing_entitlement_grants", "users"
  add_foreign_key "billing_orders", "billing_customers"
  add_foreign_key "billing_orders", "billing_subscriptions"
  add_foreign_key "billing_orders", "users"
  add_foreign_key "billing_plan_entitlements", "billing_features", column: "feature_id"
  add_foreign_key "billing_plan_entitlements", "billing_plans", column: "plan_id"
  add_foreign_key "billing_provider_mappings", "billing_plans", column: "plan_id"
  add_foreign_key "billing_subscriptions", "billing_plans", column: "plan_id"
  add_foreign_key "billing_subscriptions", "users"
  add_foreign_key "billing_usage_counters", "users"
  add_foreign_key "company_feedbacks", "interview_applications"
  add_foreign_key "connected_accounts", "users"
  add_foreign_key "email_senders", "companies"
  add_foreign_key "email_senders", "companies", column: "auto_detected_company_id"
  add_foreign_key "fit_assessments", "users"
  add_foreign_key "html_scraping_logs", "job_listings"
  add_foreign_key "html_scraping_logs", "scraping_attempts"
  add_foreign_key "interview_applications", "companies"
  add_foreign_key "interview_applications", "job_listings"
  add_foreign_key "interview_applications", "job_roles"
  add_foreign_key "interview_applications", "users"
  add_foreign_key "interview_feedbacks", "interview_rounds"
  add_foreign_key "interview_prep_artifacts", "interview_applications"
  add_foreign_key "interview_prep_artifacts", "llm_api_logs"
  add_foreign_key "interview_prep_artifacts", "users"
  add_foreign_key "interview_round_prep_artifacts", "interview_rounds"
  add_foreign_key "interview_round_types", "categories"
  add_foreign_key "interview_rounds", "interview_applications"
  add_foreign_key "interview_rounds", "interview_round_types"
  add_foreign_key "interview_skill_tags", "interview_applications", column: "interview_id"
  add_foreign_key "interview_skill_tags", "skill_tags"
  add_foreign_key "job_listings", "companies"
  add_foreign_key "job_listings", "job_roles"
  add_foreign_key "job_roles", "categories"
  add_foreign_key "llm_api_logs", "llm_prompts"
  add_foreign_key "opportunities", "interview_applications"
  add_foreign_key "opportunities", "synced_emails"
  add_foreign_key "opportunities", "users"
  add_foreign_key "resume_skills", "skill_tags"
  add_foreign_key "resume_skills", "user_resumes"
  add_foreign_key "resume_work_experience_skills", "resume_work_experiences"
  add_foreign_key "resume_work_experience_skills", "skill_tags"
  add_foreign_key "resume_work_experiences", "companies"
  add_foreign_key "resume_work_experiences", "job_roles"
  add_foreign_key "resume_work_experiences", "user_resumes"
  add_foreign_key "saved_jobs", "opportunities"
  add_foreign_key "saved_jobs", "users"
  add_foreign_key "scraped_job_listing_data", "job_listings"
  add_foreign_key "scraped_job_listing_data", "scraping_attempts"
  add_foreign_key "scraping_attempts", "job_listings"
  add_foreign_key "scraping_events", "job_listings"
  add_foreign_key "scraping_events", "scraping_attempts"
  add_foreign_key "sessions", "users"
  add_foreign_key "skill_tags", "categories"
  add_foreign_key "support_tickets", "users"
  add_foreign_key "synced_emails", "connected_accounts"
  add_foreign_key "synced_emails", "email_senders"
  add_foreign_key "synced_emails", "interview_applications"
  add_foreign_key "synced_emails", "users"
  add_foreign_key "taggings", "tags"
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
  add_foreign_key "user_target_domains", "domains"
  add_foreign_key "user_target_domains", "users"
  add_foreign_key "user_target_job_roles", "job_roles"
  add_foreign_key "user_target_job_roles", "users"
  add_foreign_key "user_work_experience_skills", "skill_tags"
  add_foreign_key "user_work_experience_skills", "user_work_experiences"
  add_foreign_key "user_work_experience_sources", "resume_work_experiences"
  add_foreign_key "user_work_experience_sources", "user_work_experiences"
  add_foreign_key "user_work_experiences", "companies"
  add_foreign_key "user_work_experiences", "job_roles"
  add_foreign_key "user_work_experiences", "users"
  add_foreign_key "users", "companies", column: "current_company_id"
  add_foreign_key "users", "job_roles", column: "current_job_role_id"
end
