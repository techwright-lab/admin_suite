# frozen_string_literal: true

require "test_helper"

class SavedJobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, email_verified_at: Time.current)
    sign_in_as(@user)
  end

  test "destroy archives saved job instead of deleting" do
    saved_job = create(:saved_job, :from_url, user: @user, title: "Unique Saved Job Title")

    assert_no_difference "SavedJob.count" do
      delete saved_job_path(saved_job)
    end

    assert_redirected_to saved_jobs_path
    saved_job.reload
    assert_equal "archived", saved_job.status
    assert_equal "removed_saved_job", saved_job.archived_reason
    assert saved_job.archived_at.present?
  end

  test "restore returns archived saved job to active and clears archive metadata" do
    saved_job = create(:saved_job, :from_url, :archived, user: @user)

    post restore_saved_job_path(saved_job)

    assert_redirected_to saved_jobs_path
    saved_job.reload
    assert_equal "active", saved_job.status
    assert_nil saved_job.archived_reason
    assert_nil saved_job.archived_at
  end

  test "index excludes archived saved jobs" do
    archived_job = create(:saved_job, :from_url, user: @user, title: "Archived Job Title")
    archived_job.archive_removed!
    active_job = create(:saved_job, :from_url, user: @user, title: "Active Job Title")

    get saved_jobs_path

    assert_response :success
    assert_match(/Active Job Title/, response.body)
    assert_no_match(/Archived Job Title/, response.body)
  end
end


