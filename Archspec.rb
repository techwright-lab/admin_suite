# No BaseService, agent, or Ai::Client rule: this engine has none.
# test/ and test/dummy/test stay out of the scan; dummy app code is the host, not a fixture.
# Generators may reference the engine; they may not depend on controllers or dummy models.

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
queries.cannot_use :controllers, :helpers, :models, :mcp
legacy_admin.cannot_use :controllers, :helpers, :models
generators.cannot_use :controllers, :models

mcp.cannot_call :save, :save!, :update, :update!, :destroy, :destroy!,
  :create, :create!, :upsert, :upsert_all, :delete_all, :update_all,
  :insert_all, :touch, receiver: :any
ui.cannot_call :save, :save!, :update, :update!, :destroy, :destroy!,
  :create, :create!, :upsert, :upsert_all, :delete_all, :update_all,
  :insert_all, :touch, receiver: :any
queries.cannot_call :save, :save!, :update, :update!, :destroy, :destroy!,
  :create, :create!, :upsert, :upsert_all, :delete_all, :update_all,
  :insert_all, receiver: :any
