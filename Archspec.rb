# Architecture spec for the engine, its namespace, and the test dummy.
# Enforced by `bin/archspec check` and `bin/archspec-baseline` (bin/ci + the
# hosted CI architecture job). Accepted legacy violations live in
# archspec_todo.yml. Refresh only deliberately via
# `bin/archspec check --update-todo`. Neither CI path passes that flag.
# Checks do not boot Rails, the database, or the network.
#
# Enabled rules:
# - architecture :rails over engine controllers/helpers and the dummy app's
#   controllers, helpers, and models. Mailers, jobs, and services are declared
#   so the preset applies if those directories appear.
# - preset :ruby_conventions.
# - Engine library code may not depend on controllers, helpers, or dummy models.
# - MCP tools, UI renderers, and AdminSuite::Query may not persist.
# - Dummy models may not depend on controllers or helpers (rails preset).
#
# Justified exceptions:
# - No BaseService, agent, or Ai::Client rule. This engine has none.
# - test/ fixtures and test/dummy/test are not in the scan. Dummy app code is
#   included because it is the engine's Rails host, not a fixture.
# - Generators may reference the engine; they may not depend on controllers
#   or dummy models.

todo "archspec_todo.yml"

architecture :rails, components: {
  controllers: [ "app/controllers/**/*.rb", "test/dummy/app/controllers/**/*.rb" ],
  models: "test/dummy/app/models/**/*.rb",
  helpers: [ "app/helpers/**/*.rb", "test/dummy/app/helpers/**/*.rb" ],
  mailers: "app/mailers/**/*.rb",
  jobs: "app/jobs/**/*.rb",
  services: "app/services/**/*.rb"
}
preset :ruby_conventions

engine = component :engine, in: "lib/admin_suite/**/*.rb", except: [
  "lib/admin_suite/mcp/**/*.rb",
  "lib/admin_suite/ui/**/*.rb",
  "lib/admin_suite/renderers/**/*.rb",
  "lib/admin_suite/query.rb"
]
mcp = component :mcp, in: "lib/admin_suite/mcp/**/*.rb"
ui = component :ui, in: [ "lib/admin_suite/ui/**/*.rb", "lib/admin_suite/renderers/**/*.rb" ]
queries = component :queries, in: "lib/admin_suite/query.rb"
legacy_admin = component :legacy_admin, in: "lib/admin/**/*.rb"
generators = component :generators, in: "lib/generators/**/*.rb"

controllers.can_only_use :engine, :mcp, :ui, :queries, :legacy_admin
models.cannot_use :engine, :mcp, :ui, :queries, :legacy_admin, :generators
jobs.cannot_use :controllers, :helpers
engine.cannot_use :controllers, :helpers, :models
mcp.cannot_use :controllers, :helpers, :models
ui.cannot_use :controllers, :helpers, :models
queries.cannot_use :controllers, :helpers, :models
legacy_admin.cannot_use :controllers, :helpers, :models
generators.cannot_use :controllers, :models

ui.cannot_call :save, :save!, :update, :update!, :destroy, :destroy!,
  :create, :create!, :upsert, :upsert_all, :delete_all, :update_all,
  :insert_all, :touch, receiver: :any
queries.cannot_call :save, :save!, :update, :update!, :destroy, :destroy!,
  :create, :create!, :upsert, :upsert_all, :delete_all, :update_all,
  :insert_all, receiver: :any
