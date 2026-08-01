# frozen_string_literal: true

module AdminSuite
  # Zeitwerk integration for host apps, extracted from the engine's
  # "admin_suite.host_dsl_ignore" initializer so it is directly testable
  # against the real Zeitwerk-loader interface instead of a copy of it.
  #
  # Host apps may store AdminSuite DSL files under `app/admin_suite/**` and
  # `app/admin/portals/**`. These are side-effect DSL files (they do not
  # define constants), so Zeitwerk must ignore them to avoid eager-load
  # `Zeitwerk::NameError`s in production. Host apps may also use `Admin::*`
  # constants inside `app/admin/**`, which needs a namespace mapping since
  # Rails' default autoload root (`app/admin`) otherwise expects top-level
  # constants.
  class HostAutoloadPolicy
    class << self
      # @param app [Rails::Application] the host application
      # @param loaders [#each, #main] defaults to `Rails.autoloaders`. Tests
      #   may inject a plain Array of fake loaders; `main` is used for
      #   `push_dir` (falling back to the first loader when the given
      #   collection doesn't respond to `#main`) and every loader in the
      #   collection is given a chance to `#ignore` the DSL directories.
      # @return [void]
      def apply!(app, loaders: Rails.autoloaders)
        root = app.root

        admin_suite_app_dir = root.join("app/admin_suite")
        admin_dir = root.join("app/admin")
        admin_portals_dir = root.join("app/admin/portals")

        # If the host uses `Admin::*` constants inside `app/admin/**`, Rails' default
        # autoload root (`app/admin`) would expect top-level constants like
        # `Resources::UserResource`. We fix that by mapping `app/admin` to `Admin`.
        # This avoids requiring host apps to add their own Zeitwerk initializer.
        admin_dir_mapped = admin_dir.exist? && host_admin_namespace_files?(admin_dir)

        if admin_dir_mapped
          admin_dir_s = admin_dir.to_s
          app.config.autoload_paths.delete(admin_dir_s)
          app.config.eager_load_paths.delete(admin_dir_s)

          # Ensure `Admin` exists so Zeitwerk can use it as a namespace.
          ensure_module!(Object, :Admin)

          main_loader(loaders).push_dir(admin_dir, namespace: ::Admin)
          # `app/admin/renderers/foo_renderer.rb` now resolves to
          # `Admin::Renderers::FooRenderer` under this same push_dir, with no
          # extra work: the whole `app/admin` tree (including `renderers/`) is
          # namespaced under `::Admin` by Zeitwerk's directory conventions.
        end

        # A host with ONLY DSL files under `app/admin` (no `Admin::*` constants
        # anywhere) never takes the branch above, so `app/admin` remains a
        # default Rails autoload root mapping to top-level constants. Without
        # this, `app/admin/renderers/foo_renderer.rb` would need to define a
        # top-level `Renderers::FooRenderer` instead of the documented
        # `Admin::Renderers::FooRenderer`, and `host_renderer_class` in
        # base_helper.rb would never find it. Map `app/admin/renderers`
        # explicitly in that case.
        renderers_dir = root.join("app/admin/renderers")
        if renderers_dir.exist? && !admin_dir_mapped
          ensure_module!(Object, :Admin)
          ensure_module!(::Admin, :Renderers)
          main_loader(loaders).push_dir(renderers_dir, namespace: ::Admin::Renderers)
        end

        each_loader(loaders) do |loader|
          loader.ignore(admin_suite_app_dir) if admin_suite_app_dir.exist?

          next unless admin_portals_dir.exist?

          loader.ignore(admin_portals_dir) if contains_admin_suite_portal_dsl?(admin_portals_dir)
        end
      end

      # True if any file under app/admin (excluding app/admin/portals)
      # appears to define `Admin::*` constants.
      #
      # @param admin_dir [Pathname]
      # @return [Boolean]
      def host_admin_namespace_files?(admin_dir)
        Dir[admin_dir.join("**/*.rb").to_s].any? do |file|
          next false if file.include?("/portals/")

          content = File.binread(file)
          content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

          content.match?(/\b(module|class)\s+Admin\b/) ||
            content.match?(/\b(module|class)\s+Admin::/)
        rescue StandardError
          false
        end
      end

      # True if any file under `admin_portals_dir` uses the `AdminSuite.portal`
      # DSL (as opposed to defining real constants).
      #
      # @param admin_portals_dir [Pathname]
      # @return [Boolean]
      def contains_admin_suite_portal_dsl?(admin_portals_dir)
        portal_files = Dir[admin_portals_dir.join("**/*.rb").to_s]
        portal_files.any? do |file|
          content = File.binread(file)
          content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
          portal_dsl_pattern = /(::)?AdminSuite\s*\.\s*portal\b/
          portal_dsl_pattern.match?(content)
        rescue StandardError
          false
        end
      end

      private

      def main_loader(loaders)
        loaders.respond_to?(:main) ? loaders.main : Array(loaders).first
      end

      # `module Foo; end` can't appear inside a method body (it's a syntax
      # error there, unlike inside a block), so namespace creation goes
      # through `const_set` instead.
      def ensure_module!(parent, name)
        return if parent.const_defined?(name, false)

        parent.const_set(name, Module.new)
      end

      def each_loader(loaders, &block)
        loaders.each(&block)
      end
    end
  end
end
