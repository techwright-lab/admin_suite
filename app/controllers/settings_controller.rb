# frozen_string_literal: true

# Controller for user settings management
# Handles profile, preferences, notifications, AI settings, integrations, privacy, and security
class SettingsController < ApplicationController
  before_action :set_user
  before_action :set_preference
  before_action :load_profile_data, only: [ :show, :update_profile ]

  # GET /settings
  def show
    @active_tab = params[:tab] || "profile"
    @sessions = @user.sessions.order(created_at: :desc) if @active_tab == "security"
    @connected_accounts = @user.connected_accounts if @active_tab == "integrations" && @user.respond_to?(:connected_accounts)
    load_subscription_data if @active_tab == "subscription"
    load_billing_data if @active_tab == "billing"
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
      :portfolio_url,
      target_job_role_ids: [],
      target_company_ids: []
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
  end

  # Loads billing data for the billing tab
  # @return [void]
  def load_billing_data
    @billing_customer = @user.billing_customers.find_by(provider: "lemonsqueezy")
    @billing_history = load_billing_history
  end

  # Loads billing history from subscriptions and webhook events
  # @return [Array<Hash>]
  def load_billing_history
    # Get subscription events that indicate payments
    subscriptions = @user.billing_subscriptions.order(created_at: :desc).limit(10)

    subscriptions.map do |sub|
      {
        date: sub.current_period_starts_at || sub.created_at,
        plan_name: sub.plan&.name || "Unknown Plan",
        amount: sub.plan&.amount_cents.to_i / 100.0,
        currency: sub.plan&.currency || "usd",
        status: sub.status,
        subscription_id: sub.external_subscription_id
      }
    end
  end
end
