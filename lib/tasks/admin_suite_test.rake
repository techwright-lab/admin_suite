# frozen_string_literal: true

require "rake/testtask"

namespace :admin_suite do
  desc "Run AdminSuite gem tests (Minitest)"
  Rake::TestTask.new(:test) do |t|
    t.libs << "test"
    t.pattern = "test/**/*_test.rb"
  end
end
