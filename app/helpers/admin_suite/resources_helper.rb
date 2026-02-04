# frozen_string_literal: true

module AdminSuite
  module ResourcesHelper
    # Intentionally empty.
    #
    # `AdminSuite::ApplicationController` installs `AdminSuite::BaseHelper` for all
    # engine views. That helper provides rich rendering for:
    # - index column types (e.g. `:toggle`, `:label`)
    # - show formatters (markdown/json/code/attachments)
    #
    # Defining `render_column_value` / `format_show_value` here would override
    # those implementations and silently break functionality.
  end
end
