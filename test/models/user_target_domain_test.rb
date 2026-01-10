# frozen_string_literal: true

require "test_helper"

class UserTargetDomainTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @domain = Domain.create!(name: "Test Domain #{SecureRandom.hex(4)}")
  end

  test "validates presence of user" do
    target = UserTargetDomain.new(domain: @domain)
    assert_not target.valid?
    assert_includes target.errors[:user], "must exist"
  end

  test "validates presence of domain" do
    target = UserTargetDomain.new(user: @user)
    assert_not target.valid?
    assert_includes target.errors[:domain], "must exist"
  end

  test "validates uniqueness of domain_id scoped to user_id" do
    UserTargetDomain.create!(user: @user, domain: @domain)
    duplicate = UserTargetDomain.new(user: @user, domain: @domain)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:domain_id], "has already been taken"
  end

  test "allows same domain for different users" do
    other_user = create(:user)
    UserTargetDomain.create!(user: @user, domain: @domain)
    target = UserTargetDomain.new(user: other_user, domain: @domain)
    assert target.valid?
  end

  test "ordered scope sorts by priority then created_at" do
    domain2 = Domain.create!(name: "Domain 2 #{SecureRandom.hex(4)}")
    target1 = UserTargetDomain.create!(user: @user, domain: @domain, priority: 2)
    target2 = UserTargetDomain.create!(user: @user, domain: domain2, priority: 1)

    ordered = @user.user_target_domains.ordered
    assert_equal target2, ordered.first
    assert_equal target1, ordered.last
  end

  test "belongs_to user" do
    target = UserTargetDomain.new(user: @user, domain: @domain)
    assert_equal @user, target.user
  end

  test "belongs_to domain" do
    target = UserTargetDomain.new(user: @user, domain: @domain)
    assert_equal @domain, target.domain
  end
end
