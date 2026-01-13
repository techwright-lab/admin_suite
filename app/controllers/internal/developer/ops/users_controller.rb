# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class UsersController < Internal::Developer::ResourcesController
        # POST /internal/developer/ops/users/:id/resend_verification_email
        # Resends the email verification link to the user
        def resend_verification_email
          if resource.email_verified?
            redirect_to resource_url(resource), alert: "User email is already verified."
          else
            UserMailer.verify_email(resource).deliver_later
            redirect_to resource_url(resource), notice: "Verification email sent to #{resource.email_address}."
          end
        end

        # POST /internal/developer/ops/users/:id/grant_admin
        # Grants admin privileges to the user
        def grant_admin
          resource.update!(is_admin: true)
          redirect_to resource_url(resource), notice: "Granted admin privileges to #{resource.display_name}."
        end

        # POST /internal/developer/ops/users/:id/revoke_admin
        # Revokes admin privileges from the user
        def revoke_admin
          if resource == Current.user
            redirect_to resource_url(resource), alert: "You cannot revoke your own admin privileges."
          else
            resource.update!(is_admin: false)
            redirect_to resource_url(resource), notice: "Revoked admin privileges from #{resource.display_name}."
          end
        end

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
