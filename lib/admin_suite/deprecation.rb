# frozen_string_literal: true

module AdminSuite
  # Per-process, once-per-key deprecation warning support.
  #
  # Originally lived only on `AdminSuite::Renderers::LegacyGleania` (the four
  # legacy Gleania renderers); pulled out here so `Admin::Base::Resource`
  # (the `exportable` no-op) and the legacy `config.custom_renderers` proc
  # path can share the same once-per-key behavior instead of re-implementing
  # it, without becoming a general-purpose deprecation framework.
  #
  # `extend` this module to get an independent `@warned_keys` store scoped to
  # the extending object (a module, or -- via singleton-method inheritance --
  # each subclass of a class that extends it).
  module Deprecation
    # Swappable sink for the deprecation message -- a method rather than an
    # attribute so `Minitest::Mock#stub(:warn_once_sink, replacement)` can
    # intercept it directly: `stub` invokes the replacement with whatever
    # arguments the stubbed call site passes (here, the message), rather
    # than substituting it as a return value. Defaults to logging via
    # `Rails.logger`.
    #
    # @param msg [String]
    # @return [void]
    def warn_once_sink(msg)
      Rails.logger&.warn(msg)
    end

    # @return [void]
    def reset_deprecation_notices!
      @warned_keys = {}
    end

    # Fires the deprecation sink at most once per `key` per process (per
    # extending object).
    #
    # @param key [Object] anything hashable identifying the deprecated thing
    # @param message [String] fully-formatted deprecation message
    # @return [void]
    def warn_once(key, message)
      @warned_keys ||= {}
      return if @warned_keys[key]

      @warned_keys[key] = true
      warn_once_sink(message)
    end
  end
end
