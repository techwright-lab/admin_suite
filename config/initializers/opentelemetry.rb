# frozen_string_literal: true

require "uri"
require "opentelemetry/sdk"
require "opentelemetry-logs-api"
require "opentelemetry-logs-sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/exporter/otlp_logs"
require "opentelemetry-instrumentation-logger"
require "opentelemetry-instrumentation-net_http"
require "opentelemetry-instrumentation-pg"
require "opentelemetry-instrumentation-rails"

if Rails.env.production?
  OpenTelemetry::SDK.configure do |c|
    c.use_all # auto-include all instrumentation
    c.logger = Logger.new(STDOUT)
    c.service_name = "gleania"
    c.service_version = ENV["KAMAL_VERSION"]&.first(9).to_s
  end
end
