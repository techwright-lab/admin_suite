# frozen_string_literal: true

# Configure Zeitwerk to properly load the admin framework
#
# The app/admin directory contains:
# - base/      -> Admin::Base::*
# - portals/   -> Admin::Portals::*
# - resources/ -> Admin::Resources::*
#
# We configure Zeitwerk to treat app/admin as mapping to the Admin:: namespace

# Define the Admin module before configuring Zeitwerk
module Admin
  module Base; end
  module Resources; end
  module Portals; end
end

Rails.autoloaders.main.push_dir(
  Rails.root.join("app/admin"),
  namespace: Admin
)

# Eager load the base resource class after Rails initializes
Rails.application.config.after_initialize do
  require Rails.root.join("app/admin/base/resource.rb").to_s
end
