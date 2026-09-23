# frozen_string_literal: true

require "minitest/autorun" unless defined?(Rails)
require "yaml"
require "open3"
require "tmpdir"
require "fileutils"

class ArchspecEnforcementTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_pull_request_architecture_job_is_fail_closed_and_matches_bin_ci
    workflow = YAML.load_file(File.join(ROOT, ".github/workflows/ci.yml"))
    job = workflow.fetch("jobs").fetch("architecture")
    assert_equal "ubuntu-latest", job["runs-on"]
    assert_nil job["continue-on-error"]
    assert_nil job["if"]

    commands = job.fetch("steps").filter_map { |step| step["run"] }
    assert_includes commands, "bin/archspec check"
    assert_includes commands, "bin/archspec-baseline"
    assert commands.none? { |command| command.include?("continue-on-error") || command.include?("[ -f") }

    ci = File.read(File.join(ROOT, "bin/ci"))
    assert_includes ci, 'step "Architecture: ArchSpec" bin/archspec check'
    assert_includes ci, 'step "Architecture: baseline cap" bin/archspec-baseline'
    refute_match(/if \[ -f bin\/archspec \]/, ci)
    refute_match(/if \[ -f Archspec\.rb \]/, ci)
    assert_equal "read", job.dig("permissions", "contents")
  end

  def test_mcp_cannot_call_rejects_a_write
    spec = File.read(File.join(ROOT, "Archspec.rb"))
    rule = spec[/mcp\.cannot_call\b.*?receiver: :any/m]
    assert rule, "mcp.cannot_call must forbid writes on any receiver"
    refute_match(/ui\.cannot_call/, rule)
    assert_match(/queries\.cannot_use\b[^\n]*:mcp\b/, spec)

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "lib/admin_suite/mcp"))
      File.write(File.join(dir, "Archspec.rb"), spec)
      File.write(File.join(dir, "archspec_todo.yml"), File.read(File.join(ROOT, "archspec_todo.yml")))
      File.write(File.join(dir, "lib/admin_suite/mcp/probe.rb"), <<~RUBY)
        module AdminSuite
          module Mcp
            class Probe
              def call(record)
                record.save
              end
            end
          end
        end
      RUBY

      output, status = run_archspec(dir, "check")
      refute status.success?, output
      assert_match(/must not call #save/, output)
    end
  end

  def test_missing_and_invalid_configuration_fail
    Dir.mktmpdir do |dir|
      _output, status = run_archspec(dir, "check", "--config", File.join(dir, "missing.rb"))
      refute status.success?
    end

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Archspec.rb"), "this is not ruby (\n")
      _output, status = run_archspec(dir, "check")
      refute status.success?
    end
  end

  def test_stale_baseline_id_fails_and_current_set_passes
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/models"))
      File.write(File.join(dir, "app/models/widget.rb"), "class Widget\nend\n")
      File.write(File.join(dir, "Archspec.rb"), <<~CONFIG)
        todo "archspec_todo.yml"
        component :models, in: "app/models/**/*.rb"
        models.cannot_reference_constants "Nope"
      CONFIG
      File.write(File.join(dir, "archspec_todo.yml"), <<~YAML)
        ---
        violations: []
      YAML

      _output, status = run_baseline(dir)
      assert status.success?, "empty matching baseline must pass"

      File.write(File.join(dir, "archspec_todo.yml"), <<~YAML)
        ---
        violations:
        - id: deadbeefdeadbeefdeadbeef
          rule: constants.forbid
          path: app/models/widget.rb
          line: 1
          message: gone
      YAML
      output, status = run_baseline(dir)
      refute status.success?
      assert_match(/stale deadbeefdeadbeefdeadbeef/, output)
    end
  end

  private

  def run_archspec(dir, *args)
    Open3.capture2e({ "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile") }, File.join(ROOT, "bin/archspec"), *args, chdir: dir)
  end

  def run_baseline(dir)
    Open3.capture2e({ "BUNDLE_GEMFILE" => File.join(ROOT, "Gemfile") }, File.join(ROOT, "bin/archspec-baseline"), chdir: dir)
  end
end
