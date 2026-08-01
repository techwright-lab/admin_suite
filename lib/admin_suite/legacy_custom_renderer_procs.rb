# frozen_string_literal: true

module AdminSuite
  # Deprecation warning for `config.custom_renderers[:key] = ->(record, view) {}`
  # procs (deprecated on paper since 0.4.0 — see CHANGELOG). They still take
  # top precedence in `render_custom_section`, unchanged: Task 3 has tests
  # pinning that. Unlike the four legacy Gleania renderers, though, these
  # warned nothing at runtime, so a host mid-migration (trust_growth has 23
  # of them) has no signal to notice by. Warns once per key per process.
  module LegacyCustomRendererProcs
    extend AdminSuite::Deprecation

    DEPRECATION_MESSAGE_FORMAT =
      "AdminSuite: config.custom_renderers[:%<key>s] is a deprecated proc " \
      "and will be removed in 0.6.0. Migrate to an AdminSuite::Renderer subclass."

    class << self
      # Fires the deprecation sink at most once per `key` per process.
      # `warn_once_sink` and `reset_deprecation_notices!` come from
      # `AdminSuite::Deprecation`, extended above.
      #
      # @param key [Symbol]
      # @return [void]
      def warn_once(key)
        super(key, format(DEPRECATION_MESSAGE_FORMAT, key: key))
      end
    end
  end
end
