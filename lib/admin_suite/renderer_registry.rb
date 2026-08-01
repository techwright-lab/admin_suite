# frozen_string_literal: true

module AdminSuite
  # Maps panel `render:` keys to Renderer classes.
  #
  # Two independent stores, so a host following the deprecation advice
  # printed for a legacy renderer (or simply overriding a built-in) actually
  # takes effect:
  #
  # - `register` / `lookup` — explicit registrations: a host initializer (or
  #   a spec) calling `RendererRegistry.register(:key, SomeClass)`.
  # - `register_default` / `lookup_default` — the gem's own boot-time
  #   registrations (the four built-ins, their two aliases, and the four
  #   deprecated Gleania renderers — see `lib/admin_suite.rb`).
  #
  # `AdminSuite::BaseHelper#render_custom_section` checks `lookup`, then a
  # host `Admin::Renderers::<Key>Renderer` class, then `lookup_default` —
  # explicit beats host-class beats gem-default. See that method for the
  # full precedence chain (legacy `config.custom_renderers` procs come
  # first, ahead of all of this).
  module RendererRegistry
    @registry = {}
    @defaults = {}

    class << self
      # Explicit registration (host apps, initializers, specs). Takes
      # precedence over everything but a legacy `config.custom_renderers`
      # proc.
      def register(key, klass)
        @registry[key.to_sym] = klass
      end

      # Gem boot-time registration. Only consulted after a host's own
      # explicit registration and its `Admin::Renderers::<Key>Renderer`
      # class have both been checked and found nothing.
      def register_default(key, klass)
        @defaults[key.to_sym] = klass
      end

      # @return [Class, nil] the explicit registration for `key`, if any
      def lookup(key)
        @registry[key.to_sym]
      end

      # @return [Class, nil] the gem-default registration for `key`, if any
      def lookup_default(key)
        @defaults[key.to_sym]
      end

      # Every key known to either store (explicit ∪ default).
      #
      # @return [Array<Symbol>]
      def registered
        (@defaults.keys | @registry.keys)
      end

      # Test-support only. Removes a single *explicit* registration.
      #
      # There is intentionally no bulk `reset!`, and this never touches the
      # default store: AdminSuite's own built-in renderers register
      # themselves as defaults at require time, once, for the life of the
      # process. Specs that register scratch/probe renderers via `register`
      # should call `unregister` for exactly the key(s) they added, in a
      # teardown.
      def unregister(key)
        @registry.delete(key.to_sym)
      end
    end
  end
end
