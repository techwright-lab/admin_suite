# frozen_string_literal: true

# Concern for pagination functionality using Pagy
#
# Provides standardized pagination helpers for controllers.
# Include this concern in ApplicationController or individual controllers.
#
# @example
#   class UsersController < ApplicationController
#     include Paginatable
#
#     def index
#       @pagy, @users = pagy(User.all)
#     end
#   end
#
module Paginatable
  extend ActiveSupport::Concern

  included do
    include Pagy::Backend
  end
end

