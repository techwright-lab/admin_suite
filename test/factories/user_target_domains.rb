# frozen_string_literal: true

FactoryBot.define do
  factory :user_target_domain do
    user
    domain
  end
end
