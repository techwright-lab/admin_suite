# frozen_string_literal: true

require "test_helper"

class DomainTest < ActiveSupport::TestCase
  test "validates presence of name" do
    domain = Domain.new(name: nil)
    assert_not domain.valid?
    assert_includes domain.errors[:name], "can't be blank"
  end

  test "validates uniqueness of name" do
    Domain.create!(name: "FinTech")
    duplicate = Domain.new(name: "FinTech")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "normalizes name by stripping whitespace" do
    domain = Domain.new(name: "  SaaS  ")
    domain.valid?
    assert_equal "SaaS", domain.name
  end

  test "generates slug from name on validation" do
    domain = Domain.new(name: "AI/ML")
    domain.valid?
    assert_equal "aiml", domain.slug
  end

  test "alphabetical scope orders by name" do
    Domain.destroy_all
    z_domain = Domain.create!(name: "Zebra Tech")
    a_domain = Domain.create!(name: "Alpha Tech")

    domains = Domain.alphabetical
    assert_equal a_domain, domains.first
    assert_equal z_domain, domains.last
  end

  test "search scope finds domains by name" do
    Domain.destroy_all
    fintech = Domain.create!(name: "FinTech")
    Domain.create!(name: "Healthcare")

    results = Domain.search("fin")
    assert_includes results, fintech
    assert_equal 1, results.count
  end

  test "display_name returns name" do
    domain = Domain.new(name: "E-commerce")
    assert_equal "E-commerce", domain.display_name
  end

  test "has_many user_target_domains association" do
    domain = Domain.create!(name: "Test Domain")
    assert_respond_to domain, :user_target_domains
    assert_respond_to domain, :users_targeting
  end
end
