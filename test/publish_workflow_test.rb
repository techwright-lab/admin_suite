# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class PublishWorkflowTest < Minitest::Test
  WORKFLOW_PATH = File.expand_path("../.github/workflows/publish.yml", __dir__)

  def setup
    @source = File.read(WORKFLOW_PATH)
    @workflow = YAML.load_file(WORKFLOW_PATH)
    @job = @workflow.fetch("jobs").fetch("publish")
    @steps = @job.fetch("steps")
  end

  def test_publishing_uses_the_release_environment_and_job_scoped_oidc
    assert_equal "release", @job["environment"]
    assert_equal "write", @job.fetch("permissions")["id-token"]
    assert_equal "write", @job.fetch("permissions")["contents"]
    refute @workflow.fetch("permissions", {}).key?("id-token")
  end

  def test_automatic_publishing_requires_successful_main_push_ci
    condition = @job.fetch("if")
    assert_includes condition, "github.repository == 'techwright-lab/admin_suite'"
    assert_includes condition, "github.event_name == 'workflow_run'"
    assert_includes condition, "github.event.workflow_run.conclusion == 'success'"
    assert_includes condition, "github.event.workflow_run.event == 'push'"
    assert_includes condition, "github.event.workflow_run.head_branch == 'main'"
    assert_includes condition, "github.event.workflow_run.head_repository.full_name == github.repository"
    assert_includes condition, "github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'"
  end

  def test_credentials_are_pinned_conditional_and_before_the_push
    credentials_index = @steps.index { |step| step["name"] == "Configure RubyGems trusted publishing" }
    refute_nil credentials_index
    credentials = @steps.fetch(credentials_index)
    push_index = @steps.index { |step| step["name"] == "Publish to RubyGems" }
    push = @steps.fetch(push_index)

    assert_equal "rubygems/configure-rubygems-credentials@dc5a8d8553e6ee01fc26761a49e99e733d17954a", credentials["uses"]
    assert_equal "steps.version_check.outputs.should_publish == 'true'", credentials["if"]
    assert_equal credentials["if"], push["if"]
    assert_operator credentials_index, :<, push_index
    refute_includes @source, "secrets.RUBYGEMS_API_KEY"
    refute_includes @source, "GEM_HOST_API_KEY:"
    refute_includes @source, "~/.gem/credentials"
    assert_includes push.fetch("run"), "gem push"
    assert_includes push.fetch("run"), "--host https://rubygems.org"
  end

  def test_releases_preserve_tested_sha_and_serialization
    checkout = @steps.find { |step| step.fetch("uses", "").start_with?("actions/checkout@") }
    assert_equal "${{ github.event.workflow_run.head_sha || github.sha }}", checkout.fetch("with")["ref"]
    assert_equal false, @workflow.fetch("concurrency")["cancel-in-progress"]
    assert_includes @source, "different contents. Bump the gem version before publishing."
    push_index = @steps.index { |step| step["name"] == "Publish to RubyGems" }
    tag_index = @steps.index { |step| step["name"] == "Create Git tag" }
    release_index = @steps.index { |step| step["name"] == "Create GitHub Release" }
    assert_operator push_index, :<, tag_index
    assert_operator tag_index, :<, release_index
  end
end
