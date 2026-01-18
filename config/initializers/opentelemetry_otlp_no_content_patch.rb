#!/usr/bin/env ruby
# frozen_string_literal: true

require "opentelemetry/exporter/otlp"
require "opentelemetry/exporter/otlp_logs"

module OtelTraceNoContentSuccessPatch
  def send_bytes(bytes, timeout:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    return OpenTelemetry::SDK::Trace::Export::FAILURE if bytes.nil?

    @metrics_reporter.record_value("otel.otlp_exporter.message.uncompressed_size", value: bytes.bytesize)

    request = Net::HTTP::Post.new(@path)
    if @compression == "gzip"
      request.add_field("Content-Encoding", "gzip")
      body = Zlib.gzip(bytes)
      @metrics_reporter.record_value("otel.otlp_exporter.message.compressed_size", value: body.bytesize)
    else
      body = bytes
    end
    request.body = body
    request.add_field("Content-Type", "application/x-protobuf")
    @headers.each { |key, value| request.add_field(key, value) }

    retry_count = 0
    timeout ||= @timeout
    start_time = OpenTelemetry::Common::Utilities.timeout_timestamp

    around_request do
      remaining_timeout = OpenTelemetry::Common::Utilities.maybe_timeout(timeout, start_time)
      return OpenTelemetry::SDK::Trace::Export::FAILURE if remaining_timeout.zero?

      @http.open_timeout = remaining_timeout
      @http.read_timeout = remaining_timeout
      @http.write_timeout = remaining_timeout
      @http.start unless @http.started?
      response = measure_request_duration { @http.request(request) }

      case response
      when Net::HTTPSuccess
        response.body # Read and discard body
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      when Net::HTTPServiceUnavailable, Net::HTTPTooManyRequests
        response.body # Read and discard body
        redo if backoff?(retry_after: response["Retry-After"], retry_count: retry_count += 1, reason: response.code)
        OpenTelemetry::SDK::Trace::Export::FAILURE
      when Net::HTTPRequestTimeOut, Net::HTTPGatewayTimeOut, Net::HTTPBadGateway
        response.body # Read and discard body
        redo if backoff?(retry_count: retry_count += 1, reason: response.code)
        OpenTelemetry::SDK::Trace::Export::FAILURE
      when Net::HTTPNotFound
        log_request_failure(response.code)
        OpenTelemetry::SDK::Trace::Export::FAILURE
      when Net::HTTPBadRequest, Net::HTTPClientError, Net::HTTPServerError
        log_status(response.body)
        @metrics_reporter.add_to_counter("otel.otlp_exporter.failure", labels: { "reason" => response.code })
        OpenTelemetry::SDK::Trace::Export::FAILURE
      when Net::HTTPRedirection
        @http.finish
        handle_redirect(response["location"])
        redo if backoff?(retry_after: 0, retry_count: retry_count += 1, reason: response.code)
      else
        @http.finish
        log_request_failure(response.code)
        OpenTelemetry::SDK::Trace::Export::FAILURE
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      retry if backoff?(retry_count: retry_count += 1, reason: "timeout")
      return OpenTelemetry::SDK::Trace::Export::FAILURE
    rescue OpenSSL::SSL::SSLError => e
      retry if backoff?(retry_count: retry_count += 1, reason: "openssl_error")
      OpenTelemetry.handle_error(exception: e, message: "SSL error in OTLP::Exporter#send_bytes")
      return OpenTelemetry::SDK::Trace::Export::FAILURE
    rescue SocketError
      retry if backoff?(retry_count: retry_count += 1, reason: "socket_error")
      return OpenTelemetry::SDK::Trace::Export::FAILURE
    rescue SystemCallError => e
      retry if backoff?(retry_count: retry_count += 1, reason: e.class.name)
      return OpenTelemetry::SDK::Trace::Export::FAILURE
    end
  end
end

module OtelLogNoContentSuccessPatch
  def send_bytes(bytes, timeout:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    return OpenTelemetry::SDK::Logs::Export::FAILURE if bytes.nil?

    request = Net::HTTP::Post.new(@path)
    if @compression == "gzip"
      request.add_field("Content-Encoding", "gzip")
      body = Zlib.gzip(bytes)
    else
      body = bytes
    end
    request.body = body
    request.add_field("Content-Type", "application/x-protobuf")
    @headers.each { |key, value| request.add_field(key, value) }

    retry_count = 0
    timeout ||= @timeout
    start_time = OpenTelemetry::Common::Utilities.timeout_timestamp

    around_request do
      remaining_timeout = OpenTelemetry::Common::Utilities.maybe_timeout(timeout, start_time)
      return OpenTelemetry::SDK::Logs::Export::FAILURE if remaining_timeout.zero?

      @http.open_timeout = remaining_timeout
      @http.read_timeout = remaining_timeout
      @http.write_timeout = remaining_timeout
      @http.start unless @http.started?
      response = @http.request(request)

      case response
      when Net::HTTPSuccess
        response.body # Read and discard body
        OpenTelemetry::SDK::Logs::Export::SUCCESS
      when Net::HTTPServiceUnavailable, Net::HTTPTooManyRequests
        response.body # Read and discard body
        handle_http_error(response)
        redo if backoff?(retry_after: response["Retry-After"], retry_count: retry_count += 1)
        OpenTelemetry::SDK::Logs::Export::FAILURE
      when Net::HTTPRequestTimeOut, Net::HTTPGatewayTimeOut, Net::HTTPBadGateway
        response.body # Read and discard body
        handle_http_error(response)
        redo if backoff?(retry_count: retry_count += 1)
        OpenTelemetry::SDK::Logs::Export::FAILURE
      when Net::HTTPNotFound
        handle_http_error(response)
        OpenTelemetry::SDK::Logs::Export::FAILURE
      when Net::HTTPBadRequest, Net::HTTPClientError, Net::HTTPServerError
        log_status(response.body)
        OpenTelemetry::SDK::Logs::Export::FAILURE
      when Net::HTTPRedirection
        @http.finish
        handle_redirect(response["location"])
        redo if backoff?(retry_after: 0, retry_count: retry_count += 1)
      else
        @http.finish
        handle_http_error(response)
        OpenTelemetry::SDK::Logs::Export::FAILURE
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      OpenTelemetry.handle_error(exception: e)
      retry if backoff?(retry_count: retry_count += 1)
      return OpenTelemetry::SDK::Logs::Export::FAILURE
    rescue OpenSSL::SSL::SSLError => e
      OpenTelemetry.handle_error(exception: e)
      retry if backoff?(retry_count: retry_count += 1)
      return OpenTelemetry::SDK::Logs::Export::FAILURE
    rescue SocketError => e
      OpenTelemetry.handle_error(exception: e)
      retry if backoff?(retry_count: retry_count += 1)
      return OpenTelemetry::SDK::Logs::Export::FAILURE
    rescue SystemCallError => e
      OpenTelemetry.handle_error(exception: e)
      retry if backoff?(retry_count: retry_count += 1)
      return OpenTelemetry::SDK::Logs::Export::FAILURE
    rescue StandardError => e
      OpenTelemetry.handle_error(exception: e)
      return FAILURE
    end
  end
end

OpenTelemetry::Exporter::OTLP::Exporter.prepend(OtelTraceNoContentSuccessPatch)
OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.prepend(OtelLogNoContentSuccessPatch)
