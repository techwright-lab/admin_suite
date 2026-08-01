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
  # Reload policy (uniform across all four kinds -- `load!` itself no longer
  # branches on environment except for *how* a matching file gets loaded):
  # - `loaded?` gates every call, in every environment: once a kind is
  #   loaded, `load!(kind)` is a no-op until something explicitly clears it.
  # - In development, matching files are loaded with `load` (so editing a
  #   file's method bodies takes effect the next time it runs); everywhere
  #   else, `require` (loaded once per process, forever).
  # - Live-reload in development comes from *outside* `load!`: the engine's
  #   "admin_suite.definition_reload" initializer hooks `reset_for_new_request!`
  #   into `app.reloader.to_prepare`, which Rails runs once at boot and again
  #   on any request where it detects a change in a watched path. That clears
  #   the loaded flag (and, for kinds where it's safe, the registry) so the
  #   *next* `load!` call re-globs and reloads -- at most once per such
  #   request, not once per call. See `reset_for_new_request!` for why
  #   `:resources` is deliberately excluded from that reset.
  #
  # Error policy (generalized from ActionExecutor's pre-existing policy):
  # log the failing file and error, then re-raise in development/test so
  # broken definition files are immediately discoverable; swallow (after
  # logging) elsewhere so one bad file doesn't take down a production boot
  # or request.
  class DefinitionLoader
    # Maps each kind to:
    # - glob_key:        the AdminSuite::Configuration attribute holding glob
    #                     patterns for this kind.
    # - reset:            clears this kind's registry/definition state. Used
    #                     both by the test-facing `reset!` and, for
    #                     `dev_resettable` kinds, by `reset_for_new_request!`.
    # - loaded?:          true if this kind's definitions are already loaded.
    #                     Gates every `load!` call, in every environment.
    # - mark_loaded!:     records that a load attempt has completed. A no-op
    #                     for kinds whose "loaded" state is self-evident from
    #                     their registry (resources, portals): once something
    #                     is registered, `loaded?` is already true. Kinds
    #                     with no such registry (dashboards, actions) need an
    #                     explicit flag so an all-empty-glob load doesn't
    #                     re-scan the filesystem on every call.
    # - dev_resettable:   whether `reset_for_new_request!` (the development
    #                     live-reload hook) is allowed to reset this kind
    #                     between requests. False only for :resources --
    #                     see the comment on that entry.
    KINDS = {
      resources: {
        glob_key: :resource_globs,
        reset: -> { Admin::Base::Resource.reset_registry! },
        loaded?: -> { Admin::Base::Resource.registered_resources.any? },
        mark_loaded!: -> {},
        # Resource registration happens *only* via `Class#inherited`
        # (lib/admin/base/resource.rb), which fires on class *creation* and
        # never on reopening an already-defined class. Resetting the
        # registry and then `load`ing the same file again reopens the
        # already-defined class -- `inherited` does not refire, so nothing
        # re-populates the registry, and it stays empty for the rest of the
        # process. This bit twice within a single request in production use
        # (`navigation_items` is re-entered by `portal_color`/`portal_icon`
        # while building the sidebar), wiping the nav on the very first
        # request. So :resources is never reset for a live dev-mode reload:
        # `load!` still uses `load` (refreshing method bodies via Ruby's
        # reopen semantics), but the registered_resources array itself is
        # populated once per process and never cleared again. A resource
        # file removed from disk therefore stays registered until a real
        # process restart -- matching pre-Task-9 behavior, which had no dev
        # reload path for resources at all.
        dev_resettable: false
      },
      portals: {
        glob_key: :portal_globs,
        reset: -> { AdminSuite::PortalRegistry.reset! },
        loaded?: -> { AdminSuite::PortalRegistry.all.any? },
        mark_loaded!: -> {},
        dev_resettable: true
      },
      dashboards: {
        glob_key: :dashboard_globs,
        reset: -> { AdminSuite.reset_root_dashboard! },
        loaded?: -> { AdminSuite.config.root_dashboard_loaded },
        mark_loaded!: -> { AdminSuite.config.root_dashboard_loaded = true },
        dev_resettable: true
      },
      actions: {
        glob_key: :action_globs,
        reset: -> { Admin::Base::ActionExecutor.handlers_loaded = false },
        loaded?: -> { Admin::Base::ActionExecutor.handlers_loaded },
        mark_loaded!: -> { Admin::Base::ActionExecutor.handlers_loaded = true },
        dev_resettable: true
      }
    }.freeze

    class << self
      # Loads the definition files configured for `kind`, per the reload
      # policy above. A no-op once `kind` is loaded, until something resets
      # it (a test's explicit `reset!`, or -- in development -- the next
      # `reset_for_new_request!` triggered by Rails' reloader).
      #
      # @param kind [Symbol] one of :resources, :portals, :dashboards, :actions
      # @raise [ArgumentError] for an unrecognized kind
      # @return [void]
      def load!(kind)
        entry = kind_entry(kind)
        return if entry[:loaded?].call

        files = glob_files(entry)
        if files.empty?
          entry[:mark_loaded!].call
          return
        end

        load_files(files, mode: Rails.env.development? ? :load : :require)
        entry[:mark_loaded!].call
      end

      # Resets `kind`'s registry/definition state unconditionally. Used by
      # tests that need a clean slate regardless of `dev_resettable`.
      #
      # @param kind [Symbol]
      # @return [void]
      def reset!(kind)
        kind_entry(kind)[:reset].call
      end

      # Clears every `dev_resettable` kind's loaded state, so the next
      # `load!` call for each re-globs and reloads. Wired into
      # `app.reloader.to_prepare` by the engine, in development only (see
      # "admin_suite.definition_reload" in engine.rb) -- this is what turns
      # "load once, cache forever" into "reload at most once per request"
      # instead of `load!` resetting on every single call.
      #
      # :resources is deliberately skipped: see its KINDS entry.
      #
      # @return [void]
      def reset_for_new_request!
        KINDS.each_value { |entry| entry[:reset].call if entry[:dev_resettable] }
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
