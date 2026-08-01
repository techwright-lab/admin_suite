# frozen_string_literal: true

module AdminSuite
  # Single glob-and-load implementation for the four families of definition
  # files a host app may drop under its configured glob paths: resources,
  # portals, root dashboards, and action handlers.
  #
  # Replaces five near-duplicate loaders (three in ApplicationController, one
  # in BaseHelper, one in ActionExecutor) that each re-implemented the same
  # glob -> require/load shape with three different reload policies and, in
  # two cases, `rescue NameError; retry` used as control flow.
  #
  # Reload policy (uniform across all four kinds):
  # - development: reset the kind's registry, then `load` every matching
  #   file, on every call. This intentionally re-scans and re-evaluates
  #   definitions per request/console-call so edits are picked up live.
  # - everywhere else (test, production, etc.): `require` every matching
  #   file once; once the kind is marked loaded, subsequent calls are a
  #   no-op (no filesystem re-scan).
  #
  # Error policy (generalized from ActionExecutor's pre-existing policy):
  # log the failing file and error, then re-raise in development/test so
  # broken definition files are immediately discoverable; swallow (after
  # logging) elsewhere so one bad file doesn't take down a production boot
  # or request.
  class DefinitionLoader
    # Maps each kind to:
    # - glob_key:     the AdminSuite::Configuration attribute holding glob
    #                 patterns for this kind.
    # - reset:        clears this kind's registry/definition state. Used
    #                 both as the development reload's pre-load reset and
    #                 as the test-facing `reset!`.
    # - loaded?:      true if this kind's definitions are already loaded
    #                 (checked only outside development).
    # - mark_loaded!: records that a load attempt has completed. A no-op
    #                 for kinds whose "loaded" state is self-evident from
    #                 their registry (resources, portals): once something
    #                 is registered, `loaded?` is already true. Kinds with
    #                 no such registry (dashboards, actions) need an
    #                 explicit flag so an all-empty-glob load doesn't
    #                 re-scan the filesystem on every call.
    KINDS = {
      resources: {
        glob_key: :resource_globs,
        reset: -> { Admin::Base::Resource.reset_registry! },
        loaded?: -> { Admin::Base::Resource.registered_resources.any? },
        mark_loaded!: -> {}
      },
      portals: {
        glob_key: :portal_globs,
        reset: -> { AdminSuite::PortalRegistry.reset! },
        loaded?: -> { AdminSuite::PortalRegistry.all.any? },
        mark_loaded!: -> {}
      },
      dashboards: {
        glob_key: :dashboard_globs,
        reset: -> { AdminSuite.reset_root_dashboard! },
        loaded?: -> { AdminSuite.config.root_dashboard_loaded },
        mark_loaded!: -> { AdminSuite.config.root_dashboard_loaded = true }
      },
      actions: {
        glob_key: :action_globs,
        reset: -> { Admin::Base::ActionExecutor.handlers_loaded = false },
        loaded?: -> { Admin::Base::ActionExecutor.handlers_loaded },
        mark_loaded!: -> { Admin::Base::ActionExecutor.handlers_loaded = true }
      }
    }.freeze

    class << self
      # Loads the definition files configured for `kind`, per the reload
      # policy above.
      #
      # @param kind [Symbol] one of :resources, :portals, :dashboards, :actions
      # @raise [ArgumentError] for an unrecognized kind
      # @return [void]
      def load!(kind)
        entry = kind_entry(kind)

        if Rails.env.development?
          entry[:reset].call
          load_files(glob_files(entry), mode: :load)
          return
        end

        return if entry[:loaded?].call

        files = glob_files(entry)
        if files.empty?
          entry[:mark_loaded!].call
          return
        end

        load_files(files, mode: :require)
        entry[:mark_loaded!].call
      end

      # Resets `kind`'s registry/definition state. Used by tests (and, via
      # `load!`'s development branch, in normal operation).
      #
      # @param kind [Symbol]
      # @return [void]
      def reset!(kind)
        kind_entry(kind)[:reset].call
      end

      private

      def kind_entry(kind)
        KINDS.fetch(kind) do
          raise ArgumentError, "unknown AdminSuite::DefinitionLoader kind: #{kind.inspect}"
        end
      end

      def glob_files(entry)
        Array(AdminSuite.config.public_send(entry[:glob_key])).flat_map { |glob| Dir[glob] }.uniq
      end

      def load_files(files, mode:)
        files.each do |file|
          begin
            mode == :load ? load(file) : require(file)
          rescue StandardError, ScriptError => e
            log_error(file, e)
            raise if Rails.env.development? || Rails.env.test?
          end
        end
      end

      def log_error(file, error)
        message = "[AdminSuite] Failed to load definition file #{file}: #{error.class}: #{error.message}"

        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error(message)

          backtrace = Array(error.backtrace).take(20).join("\n")
          Rails.logger.error(backtrace) unless backtrace.empty?
        else
          warn(message)
        end
      rescue StandardError
        nil
      end
    end
  end
end
