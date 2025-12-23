# frozen_string_literal: true

require "test_helper"

class OpportunitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
  end

  test "ignore archives opportunity with reason=ignored" do
    opportunity = create(:opportunity, user: @user, status: "new")

    post ignore_opportunity_path(opportunity)

    assert_redirected_to opportunities_path
    opportunity.reload
    assert_equal "archived", opportunity.status
    assert_equal "ignored", opportunity.archived_reason
    assert opportunity.archived_at.present?
  end

  test "restore returns archived opportunity to new and clears archive metadata" do
    opportunity = create(:opportunity, :archived, user: @user)

    post restore_opportunity_path(opportunity)

    assert_redirected_to opportunities_path
    opportunity.reload
    assert_equal "new", opportunity.status
    assert_nil opportunity.archived_reason
    assert_nil opportunity.archived_at
  end
end
