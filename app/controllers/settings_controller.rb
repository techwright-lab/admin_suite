# frozen_string_literal: true

# Controller for user settings management
# Handles profile, preferences, notifications, AI settings, integrations, privacy, security,
# work experience, and targets
class SettingsController < ApplicationController
  before_action :set_user
  before_action :set_preference
  before_action :load_profile_data, only: [ :show, :update_profile ]
  before_action :set_work_experience, only: [ :update_work_experience, :destroy_work_experience ]

  # GET /settings
  def show
    @active_tab = params[:tab] || "profile"
    @sessions = @user.sessions.order(created_at: :desc) if @active_tab == "security"
    @connected_accounts = @user.connected_accounts if @active_tab == "integrations" && @user.respond_to?(:connected_accounts)
    load_subscription_data if @active_tab == "subscription"
    load_billing_data if @active_tab == "billing"
    load_work_experience_data if @active_tab == "work_experience"
    load_targets_data if @active_tab == "targets"
  end

  # PATCH /settings/profile
  def update_profile
    if @user.update(profile_params)
      respond_to_update("profile", "Profile updated successfully.")
    else
      respond_to_error("profile")
    end
  end

  # PATCH /settings/general
  def update_general
    if @preference.update(general_params)
      respond_to_update("general", "General settings updated successfully.")
    else
      respond_to_error("general")
    end
  end

  # PATCH /settings/notifications
  def update_notifications
    if @preference.update(notification_params)
      respond_to_update("notifications", "Notification settings updated successfully.")
    else
      respond_to_error("notifications")
    end
  end

  # PATCH /settings/ai_preferences
  def update_ai_preferences
    if @preference.update(ai_preference_params)
      respond_to_update("ai_preferences", "AI preferences updated successfully.")
    else
      respond_to_error("ai_preferences")
    end
  end

  # PATCH /settings/privacy
  def update_privacy
    if @preference.update(privacy_params)
      respond_to_update("privacy", "Privacy settings updated successfully.")
    else
      respond_to_error("privacy")
    end
  end

  # PATCH /settings/security
  def update_security
    if @user.update(security_params)
      redirect_to settings_path(tab: "security"), notice: "Security settings updated successfully."
    else
      @active_tab = "security"
      @sessions = @user.sessions.order(created_at: :desc)
      render :show, status: :unprocessable_entity
    end
  end

  # DELETE /settings/sessions/:id
  def destroy_session
    session_to_destroy = @user.sessions.find_by(id: params[:session_id])

    if session_to_destroy
      is_current = session_to_destroy.id == Current.session&.id
      session_to_destroy.destroy

      if is_current
        redirect_to new_session_path, notice: "You have been signed out.", status: :see_other
      else
        redirect_to settings_path(tab: "security"), notice: "Session revoked successfully.", status: :see_other
      end
    else
      redirect_to settings_path(tab: "security"), alert: "Session not found.", status: :see_other
    end
  end

  # DELETE /settings/sessions
  def destroy_all_sessions
    @user.sessions.where.not(id: Current.session&.id).destroy_all
    redirect_to settings_path(tab: "security"), notice: "All other sessions have been signed out.", status: :see_other
  end

  # DELETE /settings/disconnect/:provider
  def disconnect_provider
    return redirect_to settings_path(tab: "integrations"), alert: "Provider not specified." unless params[:provider].present?

    # If account_id is provided, disconnect that specific account
    # Otherwise, disconnect the first account found (for backward compatibility)
    if params[:account_id].present?
      account = @user.connected_accounts.find_by(id: params[:account_id], provider: params[:provider])
    else
      account = @user.connected_accounts.find_by(provider: params[:provider])
    end

    if account&.destroy
      redirect_to settings_path(tab: "integrations"), notice: "#{params[:provider].titleize} account (#{account.email}) disconnected.", status: :see_other
    else
      redirect_to settings_path(tab: "integrations"), alert: "Could not disconnect account.", status: :see_other
    end
  end

  # POST /settings/export_data
  def export_data
    # Queue a background job to generate the export
    # For now, we'll redirect with a notice
    redirect_to settings_path(tab: "privacy"), notice: "Data export has been queued. You will receive an email when it's ready."
  end

  # DELETE /settings/account
  def destroy_account
    if @user.authenticate(params[:password])
      @user.destroy
      reset_session
      redirect_to new_session_path, notice: "Your account has been permanently deleted.", status: :see_other
    else
      redirect_to settings_path(tab: "privacy"), alert: "Incorrect password. Account deletion cancelled."
    end
  end

  # POST /settings/trigger_sync
  def trigger_sync
    # If account_id is provided, sync that specific account
    # Otherwise, sync the first Google account (for backward compatibility)
    if params[:account_id].present?
      account = @user.connected_accounts.find_by(id: params[:account_id], provider: "google_oauth2")
    else
      account = @user.google_account
    end

    if account.nil?
      redirect_to settings_path(tab: "integrations"), alert: "No Gmail account connected."
      return
    end

    # Queue the sync job
    GmailSyncJob.perform_later(@user, connected_account: account)

    redirect_to settings_path(tab: "integrations"), notice: "Email sync started for #{account.email}. This may take a few moments."
  end

  # PATCH /settings/toggle_sync
  def toggle_sync
    # If account_id is provided, toggle sync for that specific account
    # Otherwise, toggle sync for the first Google account (for backward compatibility)
    if params[:account_id].present?
      account = @user.connected_accounts.find_by(id: params[:account_id], provider: "google_oauth2")
    else
      account = @user.google_account
    end

    if account.nil?
      respond_to do |format|
        format.json { render json: { success: false, error: "No Gmail account connected" }, status: :unprocessable_entity }
        format.html { redirect_to settings_path(tab: "integrations"), alert: "No Gmail account connected." }
      end
      return
    end

    # Toggle sync_enabled based on checkbox value
    sync_enabled = params[:sync_enabled] == "1"
    account.update!(sync_enabled: sync_enabled)

    respond_to do |format|
      format.json { render json: { success: true, sync_enabled: account.sync_enabled? }, status: :ok }
      format.html { redirect_to settings_path(tab: "integrations"), notice: "Sync settings updated for #{account.email}." }
    end
  end

  # =================================================================
  # Work Experience Actions
  # =================================================================

  # POST /settings/work_experience
  # Creates a new manual work experience entry
  def create_work_experience
    @work_experience = @user.user_work_experiences.build(work_experience_params)
    @work_experience.source_type = :manual

    if @work_experience.save
      respond_to do |format|
        format.html { redirect_to settings_path(tab: "work_experience"), notice: "Work experience added successfully." }
        format.json { render json: { success: true, work_experience: work_experience_json(@work_experience) }, status: :created }
        format.turbo_stream { load_work_experience_data }
      end
    else
      respond_to do |format|
        format.html do
          @active_tab = "work_experience"
          load_work_experience_data
          render :show, status: :unprocessable_entity
        end
        format.json { render json: { success: false, errors: @work_experience.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /settings/work_experience/:id
  # Updates a work experience entry (both AI-extracted and manual)
  def update_work_experience
    if @work_experience.update(work_experience_params)
      respond_to do |format|
        format.html { redirect_to settings_path(tab: "work_experience"), notice: "Work experience updated successfully." }
        format.json { render json: { success: true, work_experience: work_experience_json(@work_experience) }, status: :ok }
        format.turbo_stream { load_work_experience_data }
      end
    else
      respond_to do |format|
        format.html do
          @active_tab = "work_experience"
          load_work_experience_data
          render :show, status: :unprocessable_entity
        end
        format.json { render json: { success: false, errors: @work_experience.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /settings/work_experience/:id
  # Deletes a work experience entry
  def destroy_work_experience
    @work_experience.destroy
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "work_experience"), notice: "Work experience deleted.", status: :see_other }
      format.json { render json: { success: true }, status: :ok }
      format.turbo_stream { load_work_experience_data }
    end
  end

  # =================================================================
  # Targets Actions
  # =================================================================

  # PATCH /settings/targets
  # Updates user's target roles, companies, and domains
  def update_targets
    ActiveRecord::Base.transaction do
      update_target_job_roles if params[:target_job_role_ids]
      update_target_companies if params[:target_company_ids]
      update_target_domains if params[:target_domain_ids]
    end

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "Targets updated successfully." }
      format.json { render json: { success: true }, status: :ok }
      format.turbo_stream { load_targets_data }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: "Failed to update targets: #{e.message}" }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  # POST /settings/targets/add_role
  # Adds a single target role
  def add_target_role
    job_role = JobRole.find(params[:job_role_id])
    @user.user_target_job_roles.find_or_create_by!(job_role: job_role)

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "#{job_role.title} added to target roles." }
      format.json { render json: { success: true, job_role: { id: job_role.id, title: job_role.title, department: job_role.department_name } }, status: :ok }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: "Role not found." }
      format.json { render json: { success: false, error: "Role not found" }, status: :not_found }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  # DELETE /settings/targets/remove_role
  # Removes a single target role
  def remove_target_role
    @user.user_target_job_roles.where(job_role_id: params[:job_role_id]).destroy_all

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "Role removed from targets.", status: :see_other }
      format.json { render json: { success: true }, status: :ok }
    end
  end

  # POST /settings/targets/add_company
  # Adds a single target company
  def add_target_company
    company = Company.find(params[:company_id])
    @user.user_target_companies.find_or_create_by!(company: company)

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "#{company.name} added to target companies." }
      format.json { render json: { success: true, company: { id: company.id, name: company.name } }, status: :ok }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: "Company not found." }
      format.json { render json: { success: false, error: "Company not found" }, status: :not_found }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  # DELETE /settings/targets/remove_company
  # Removes a single target company
  def remove_target_company
    @user.user_target_companies.where(company_id: params[:company_id]).destroy_all

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "Company removed from targets.", status: :see_other }
      format.json { render json: { success: true }, status: :ok }
    end
  end

  # POST /settings/targets/add_domain
  # Adds a single target domain
  def add_target_domain
    domain = Domain.find(params[:domain_id])
    @user.user_target_domains.find_or_create_by!(domain: domain)

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "#{domain.name} added to target domains." }
      format.json { render json: { success: true, domain: { id: domain.id, name: domain.name } }, status: :ok }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: "Domain not found." }
      format.json { render json: { success: false, error: "Domain not found" }, status: :not_found }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), alert: e.message }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  # DELETE /settings/targets/remove_domain
  # Removes a single target domain
  def remove_target_domain
    @user.user_target_domains.where(domain_id: params[:domain_id]).destroy_all

    respond_to do |format|
      format.html { redirect_to settings_path(tab: "targets"), notice: "Domain removed from targets.", status: :see_other }
      format.json { render json: { success: true }, status: :ok }
    end
  end

  private

  # Responds to successful update - JSON for AJAX, redirect for regular requests
  # @param tab [String] The tab name
  # @param message [String] Success message
  def respond_to_update(tab, message)
    respond_to do |format|
      format.json { render json: { success: true, message: message }, status: :ok }
      format.html { redirect_to settings_path(tab: tab), notice: message }
      format.any { render json: { success: true, message: message }, status: :ok }
    end
  end

  # Responds to failed update - JSON for AJAX, render form for regular requests
  # @param tab [String] The tab name
  def respond_to_error(tab)
    @active_tab = tab
    errors = tab == "profile" ? @user.errors.full_messages : @preference.errors.full_messages

    respond_to do |format|
      format.json { render json: { success: false, errors: errors }, status: :unprocessable_entity }
      format.html { render :show, status: :unprocessable_entity }
      format.any { render json: { success: false, errors: errors }, status: :unprocessable_entity }
    end
  end

  # Sets the current user
  # @return [User]
  def set_user
    @user = Current.user
  end

  # Sets or builds the user preference
  # @return [UserPreference]
  def set_preference
    @preference = @user.preference || @user.build_preference
  end

  # Strong parameters for general settings
  # @return [ActionController::Parameters]
  def general_params
    params.expect(user_preference: [ :theme, :timezone, :preferred_view ])
  end

  # Strong parameters for notification settings
  # @return [ActionController::Parameters]
  def notification_params
    params.expect(user_preference: [
      :email_notifications,
      :email_weekly_digest,
      :email_interview_reminders
    ])
  end

  # Strong parameters for AI preference settings
  # @return [ActionController::Parameters]
  def ai_preference_params
    params.expect(user_preference: [
      :ai_summary_enabled,
      :ai_feedback_analysis,
      :ai_interview_prep,
      :ai_insights_frequency
    ])
  end

  # Strong parameters for privacy settings
  # @return [ActionController::Parameters]
  def privacy_params
    params.expect(user_preference: [ :data_retention_days ])
  end

  # Strong parameters for security settings (password change)
  # @return [ActionController::Parameters]
  def security_params
    params.expect(user: [ :password, :password_confirmation ])
  end

  # Strong parameters for profile settings
  # @return [ActionController::Parameters]
  def profile_params
    params.require(:user).permit(
      :name,
      :bio,
      :current_job_role_id,
      :current_company_id,
      :years_of_experience,
      :linkedin_url,
      :github_url,
      :gitlab_url,
      :twitter_url,
      :portfolio_url
    )
  end

  # Loads companies and job roles for the profile tab
  # @return [void]
  def load_profile_data
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # Loads subscription data for the subscription tab
  # @return [void]
  def load_subscription_data
    @entitlements = Billing::Entitlements.for(@user)
    @plans = Billing::Catalog.published_plans
    load_billing_action_urls
  end

  # Loads billing data for the billing tab
  # @return [void]
  def load_billing_data
    @billing_customer = @user.billing_customers.find_by(provider: "lemonsqueezy")
    @billing_history = load_billing_history
    load_billing_action_urls
    load_payment_method_info
  end

  # Loads payment method info from the latest subscription with card details.
  #
  # @return [void]
  def load_payment_method_info
    subscription_with_card = @user.billing_subscriptions
      .where(provider: "lemonsqueezy")
      .where.not(card_brand: nil)
      .order(updated_at: :desc)
      .first

    @payment_method = if subscription_with_card&.card_brand.present?
      {
        card_brand: subscription_with_card.card_brand,
        card_last_four: subscription_with_card.card_last_four
      }
    end
  end

  # Loads billing history using orders as the source of truth.
  #
  # Each order represents a payment. Orders linked to subscriptions show invoice button,
  # one-time orders (Sprint) only show receipt button.
  #
  # @return [Array<Hash>]
  def load_billing_history
    orders = @user.billing_orders
      .includes(:subscription)
      .where(provider: "lemonsqueezy")
      .where(status: "paid")
      .order(created_at: :desc)
      .limit(15)

    @subscription_history = []
    @order_history = []

    history = orders.map do |order|
      entry = build_billing_entry_from_order(order)

      if order.subscription.present?
        @subscription_history << entry
      else
        @order_history << entry
      end

      entry
    end

    history.sort_by { |e| e[:date] || Time.at(0) }.reverse
  end

  # Builds a billing history entry from an order.
  #
  # @param order [Billing::Order]
  # @return [Hash]
  def build_billing_entry_from_order(order)
    subscription = order.subscription
    plan = subscription&.plan || resolve_plan_for_order(order)
    is_one_time = plan&.one_time? || subscription.nil?

    # Get product name from order data (actual purchase), fallback to plan name
    product_name = order.metadata&.dig("raw", "first_order_item", "product_name") ||
                   plan&.name ||
                   "Payment"

    {
      type: is_one_time ? :order : :subscription,
      date: order.created_at,
      plan_name: product_name,
      amount: (order.total_cents || 0) / 100.0,
      currency: order.currency || "usd",
      status: order.status,
      order_id: order.external_order_id,
      order_number: order.order_number,
      receipt_url: order.receipt_url,
      invoice_url: subscription&.latest_invoice_url, # Only subscriptions have invoices
      is_one_time: is_one_time
    }
  end

  # Resolves the plan for an order based on variant_id in metadata.
  #
  # @param order [Billing::Order]
  # @return [Billing::Plan, nil]
  def resolve_plan_for_order(order)
    variant_id = order.metadata&.dig("raw", "first_order_item", "variant_id")
    return nil if variant_id.blank?

    mapping = Billing::ProviderMapping.find_by(provider: "lemonsqueezy", external_variant_id: variant_id.to_s)
    mapping&.plan
  end

  # Loads billing action URLs from stored metadata.
  #
  # @return [void]
  def load_billing_action_urls
    @billing_customer ||= @user.billing_customers.find_by(provider: "lemonsqueezy")
    subscription = latest_billing_subscription
    @billing_portal_url = @billing_customer&.customer_portal_url || subscription&.customer_portal_url
    @billing_update_payment_url = subscription&.update_payment_method_url
    @billing_update_subscription_url = subscription&.update_subscription_url
  end

  # Returns the most recently updated billing subscription.
  #
  # @return [Billing::Subscription, nil]
  def latest_billing_subscription
    @latest_billing_subscription ||= @user.billing_subscriptions
      .where(provider: "lemonsqueezy")
      .order(updated_at: :desc)
      .first
  end

  # =================================================================
  # Work Experience Data & Params
  # =================================================================

  # Sets work experience for update/destroy actions
  # @return [UserWorkExperience]
  def set_work_experience
    @work_experience = @user.user_work_experiences.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to settings_path(tab: "work_experience"), alert: "Work experience not found."
  end

  # Loads work experience data for the work_experience tab
  # @return [void]
  def load_work_experience_data
    @work_experiences = @user.user_work_experiences
      .reverse_chronological
      .includes(:company, :job_role, :skill_tags)
    @new_work_experience = @user.user_work_experiences.build
    @companies = Company.alphabetical.limit(200)
    @job_roles = JobRole.alphabetical.limit(200)
  end

  # Strong parameters for work experience
  # @return [ActionController::Parameters]
  def work_experience_params
    params.require(:user_work_experience).permit(
      :company_name,
      :role_title,
      :company_id,
      :job_role_id,
      :start_date,
      :end_date,
      :current,
      :responsibilities,
      :highlights
    )
  end

  # Serializes work experience for JSON response
  # @param work_experience [UserWorkExperience]
  # @return [Hash]
  def work_experience_json(work_experience)
    {
      id: work_experience.id,
      company_name: work_experience.display_company_name,
      role_title: work_experience.display_role_title,
      start_date: work_experience.start_date,
      end_date: work_experience.end_date,
      current: work_experience.current,
      source_type: work_experience.source_type,
      responsibilities: work_experience.responsibilities,
      highlights: work_experience.highlights
    }
  end

  # =================================================================
  # Targets Data & Params
  # =================================================================

  # Loads targets data for the targets tab
  # @return [void]
  def load_targets_data
    @target_job_roles = @user.target_job_roles.includes(:category).alphabetical
    @target_companies = @user.target_companies.alphabetical
    @target_domains = @user.target_domains.alphabetical

    @departments = Category.departments
    @job_roles_by_department = JobRole.alphabetical
      .includes(:category)
      .group_by { |r| r.category&.name || "Uncategorized" }

    @all_companies = Company.alphabetical
    @all_domains = Domain.alphabetical
  end

  # Updates target job roles
  # @return [void]
  def update_target_job_roles
    new_ids = Array(params[:target_job_role_ids]).map(&:to_i).reject(&:zero?)
    current_ids = @user.target_job_role_ids

    # Remove deselected
    to_remove = current_ids - new_ids
    @user.user_target_job_roles.where(job_role_id: to_remove).destroy_all if to_remove.any?

    # Add new
    to_add = new_ids - current_ids
    to_add.each do |role_id|
      @user.user_target_job_roles.find_or_create_by!(job_role_id: role_id)
    end
  end

  # Updates target companies
  # @return [void]
  def update_target_companies
    new_ids = Array(params[:target_company_ids]).map(&:to_i).reject(&:zero?)
    current_ids = @user.target_company_ids

    # Remove deselected
    to_remove = current_ids - new_ids
    @user.user_target_companies.where(company_id: to_remove).destroy_all if to_remove.any?

    # Add new
    to_add = new_ids - current_ids
    to_add.each do |company_id|
      @user.user_target_companies.find_or_create_by!(company_id: company_id)
    end
  end

  # Updates target domains
  # @return [void]
  def update_target_domains
    new_ids = Array(params[:target_domain_ids]).map(&:to_i).reject(&:zero?)
    current_ids = @user.target_domain_ids

    # Remove deselected
    to_remove = current_ids - new_ids
    @user.user_target_domains.where(domain_id: to_remove).destroy_all if to_remove.any?

    # Add new
    to_add = new_ids - current_ids
    to_add.each do |domain_id|
      @user.user_target_domains.find_or_create_by!(domain_id: domain_id)
    end
  end
end
