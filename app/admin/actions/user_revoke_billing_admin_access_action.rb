# frozen_string_literal: true

module Admin
  module Actions
    class UserRevokeBillingAdminAccessAction < Admin::Base::ActionHandler
      def call
        Billing::AdminAccessService.new(user: record, actor: current_user).revoke!
        success("Revoked Admin/Developer billing access.")
      end
    end
  end
end


