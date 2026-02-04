# frozen_string_literal: true

namespace :admin_suite do
  namespace :tailwind do
    desc "Build AdminSuite Tailwind CSS into host app builds"
    task build: :environment do
      engine_root = AdminSuite::Engine.root
      input = engine_root.join("app/assets/tailwind/admin_suite.css")
      output = Rails.root.join("app/assets/builds/admin_suite_tailwind.css")

      FileUtils.mkdir_p(output.dirname)

      cmd = [
        "tailwindcss",
        "-i", input.to_s,
        "-o", output.to_s,
        "--minify"
      ]

      puts("[admin_suite] building Tailwind CSS -> #{output}")
      success = system(*cmd)
      raise("AdminSuite Tailwind build failed (#{cmd.join(' ')})") unless success
    end
  end
end

# Ensure the engine stylesheet is present for production builds.
Rake::Task["assets:precompile"].enhance([ "admin_suite:tailwind:build" ]) if Rake::Task.task_defined?("assets:precompile")
