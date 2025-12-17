class Setting < ApplicationRecord
  AVAILABLE_SETTINGS = %w[
    user_sign_up_enabled
    user_login_enabled
    user_email_verification_enabled
    username_password_login_enabled
    magic_link_login_enabled
    oauth_login_enabled
    oauth_registration_enabled
    google_login_enabled
    google_registration_enabled
    analytics_enabled
    mixpanel_enabled
    sentry_enabled
    bugsnag_enabled
    api_population_enabled
    ashby_enabled
    greenhouse_enabled
    lever_enabled
    linkedin_enabled
    indeed_enabled
    glassdoor_enabled
    ziprecruiter_enabled
    careerbuilder_enabled
    monster_enabled
    careerjet_enabled
    js_rendering_enabled
    turnstile_enabled
  ]

  CACHE_KEY = "settings"
  CACHE_TTL = ENV.fetch("CACHE_TTL", 15.seconds).to_i

  SKIP_MUTEX = ENV.fetch("SETTINGS_SKIP_MUTEX", false).to_s == "true"
  MUTEX = Mutex.new

  validates :name, presence: true, uniqueness: { case_sensitive: true }, format: { with: /\A[a-zA-Z0-9_]+\z/, message: "can only contain letters, numbers, and underscores" }

  # after_save :purge_table_key
  after_commit :purge_cache

  AVAILABLE_SETTINGS.each do |setting|
    define_singleton_method(:"#{setting}?") do
      cached_settings[setting.to_s] == true
    end
  end

  def purge_cache
    self.class.purge_cache
  end

  class << self
    attr_accessor :disabled_cached_settings

    def toggle(name)
      raise "Setting unknown: #{name}" unless AVAILABLE_SETTINGS.include?(name)
      setting = where(name: name).first_or_create
      setting.value = !setting.value
      setting.save!
      setting.value
    end

    def set(name:, value:)
      raise "Setting unknown: #{name}" unless AVAILABLE_SETTINGS.include?(name)
      setting = where(name: name).first_or_create
      setting.value = value
      setting.save!
      setting.value
    end

    def purge_cache
      remove_instance_variable(:@cached_settings) if defined?(@cached_settings)
      Rails.cache.delete("#{CACHE_KEY}")
    end

    def cached_settings
      synchronize do
        return @cached_settings unless expired?

        value = Rails.cache.fetch(CACHE_KEY) do
          settings = Setting.all
          settings.each_with_object({}) do |setting, hash|
            hash[setting.name] = setting.value
          end
        end
        @cached_settings = value
        @cached_settings_expires_at = Time.current.to_i + CACHE_TTL

        value
      end
    end

    def expired?
      return true unless defined?(@cached_settings_expires_at)
      return true if @cached_settings_expires_at.nil?
      return true if @cached_settings_expires_at < Time.current.to_i

      @cached_settings_expires_at <= Time.current.to_i + CACHE_TTL
    end

    def synchronize(&block)
      return yield if SKIP_MUTEX

      MUTEX.synchronize(&block)
    end
  end
end
