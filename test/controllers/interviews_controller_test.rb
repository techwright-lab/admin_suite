# frozen_string_literal: true

require "test_helper"

class InterviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
    @interview = create(:interview, user: @user)
  end

  test "should get index" do
    get interviews_url
    assert_response :success
  end

  test "should get index with kanban view" do
    get interviews_url, params: { view: "kanban" }
    assert_response :success
  end

  test "should get index with list view" do
    get interviews_url, params: { view: "list" }
    assert_response :success
  end

  test "should get new" do
    get new_interview_url
    assert_response :success
  end

  test "should create interview" do
    assert_difference("Interview.count") do
      post interviews_url, params: {
        interview: {
          company: "New Company",
          role: "New Role",
          stage: :applied,
          date: 1.week.from_now
        }
      }
    end

    assert_redirected_to interviews_url
    assert_equal "New Company", Interview.last.company
  end

  test "should not create invalid interview" do
    assert_no_difference("Interview.count") do
      post interviews_url, params: {
        interview: {
          company: "",
          role: "",
          stage: :applied
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show interview" do
    get interview_url(@interview)
    assert_response :success
  end

  test "should get edit" do
    get edit_interview_url(@interview)
    assert_response :success
  end

  test "should update interview" do
    patch interview_url(@interview), params: {
      interview: {
        company: "Updated Company"
      }
    }

    assert_redirected_to interviews_url
    @interview.reload
    assert_equal "Updated Company", @interview.company
  end

  test "should not update with invalid data" do
    patch interview_url(@interview), params: {
      interview: {
        company: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy interview" do
    assert_difference("Interview.count", -1) do
      delete interview_url(@interview)
    end

    assert_redirected_to interviews_url
  end

  test "should not access other user's interview" do
    other_user = create(:user)
    other_interview = create(:interview, user: other_user)

    assert_raises(ActiveRecord::RecordNotFound) do
      get interview_url(other_interview)
    end
  end

  test "should update stage" do
    patch update_stage_interview_url(@interview), params: { stage: "offer" }
    
    @interview.reload
    assert_equal "offer", @interview.stage
  end
end

