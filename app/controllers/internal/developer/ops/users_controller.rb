# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class UsersController < Internal::Developer::ResourcesController
        # POST /internal/developer/ops/users/:id/grant_billing_admin_access
        def grant_billing_admin_access
          Billing::AdminAccessService.new(user: resource, actor: Current.user).grant!
          redirect_to resource_url(resource), notice: "Granted Admin/Developer billing access."
        end

        # POST /internal/developer/ops/users/:id/revoke_billing_admin_access
        def revoke_billing_admin_access
          Billing::AdminAccessService.new(user: resource, actor: Current.user).revoke!
          redirect_to resource_url(resource), notice: "Revoked Admin/Developer billing access."
        end

        private

        def resource_config
          Admin::Resources::UserResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

