# frozen_string_literal: true

module Scraping
  # Validates and normalizes salary ranges extracted from job listings.
  #
  # This is intentionally conservative: it's better to show no salary range than
  # to show one that is likely a false-positive (e.g., "89 - 7 USD" coming from
  # unrelated numbers in the page).
  #
  # @example
  #   res = Scraping::SalaryRangeValidator.normalize(min: 120_000, max: 150_000, currency: "USD", context_text: "per year")
  #   res[:valid] # => true
  #
  class SalaryRangeValidator
    MIN_ANNUAL_SALARY = 10_000
    MAX_ANNUAL_SALARY = 2_000_000
    CURRENCY_RE = /\A[A-Z]{3}\z/

    # Normalizes and validates a salary range.
    #
    # @param min [Numeric, String, nil]
    # @param max [Numeric, String, nil]
    # @param currency [String, nil]
    # @param context_text [String, nil] Nearby text to infer units (year/month/hour)
    # @return [Hash] { valid:, min:, max:, currency:, reason: }
    def self.normalize(min:, max:, currency:, context_text: nil)
      min_n = coerce_number(min)
      max_n = coerce_number(max)
      cur = currency.to_s.strip.upcase.presence

      return invalid("missing_salary") if min_n.nil? && max_n.nil?
      return invalid("missing_currency") if cur.blank? || cur !~ CURRENCY_RE
      return invalid("inverted_range") if min_n && max_n && max_n < min_n

      unit = infer_unit(context_text.to_s)
      return invalid("non_annual_unit") if unit && unit != :year

      return invalid("min_out_of_bounds") if min_n && !annual_amount_plausible?(min_n)
      return invalid("max_out_of_bounds") if max_n && !annual_amount_plausible?(max_n)

      {
        valid: true,
        min: min_n,
        max: max_n,
        currency: cur,
        reason: nil
      }
    end

    def self.invalid(reason)
      { valid: false, min: nil, max: nil, currency: nil, reason: reason }
    end

    def self.annual_amount_plausible?(amount)
      amount >= MIN_ANNUAL_SALARY && amount <= MAX_ANNUAL_SALARY
    end

    def self.infer_unit(text)
      t = text.to_s.downcase
      return :hour if t.match?(/\b(per\s*hour|hourly|\/\s*hr|\/\s*h)\b/)
      return :month if t.match?(/\b(per\s*month|monthly|\/\s*mo|\/\s*month)\b/)
      return :year if t.match?(/\b(per\s*year|annual|yearly|\/\s*yr|\/\s*year)\b/)

      nil
    end

    def self.coerce_number(value)
      return nil if value.nil?
      return value.to_f if value.is_a?(Numeric)

      str = value.to_s.strip
      return nil if str.blank?

      # Remove currency symbols and whitespace, keep digits, dots, commas, and "k".
      cleaned = str.gsub(/[^\d.,kK]/, "")
      return nil if cleaned.blank?

      multiplier = 1.0
      if cleaned.match?(/[kK]\z/)
        multiplier = 1000.0
        cleaned = cleaned.gsub(/[kK]\z/, "")
      end

      num = parse_decimalish(cleaned)
      num ? (num * multiplier) : nil
    end

    def self.parse_decimalish(str)
      s = str.to_s
      return nil if s.blank?

      # If it looks like a decimal-comma (e.g., "89,7"), treat comma as decimal separator.
      if s.include?(",") && !s.include?(".") && s.match?(/\A\d+,\d{1,2}\z/)
        s = s.tr(",", ".")
      else
        # Otherwise treat commas as thousands separators.
        s = s.delete(",")
      end

      Float(s)
    rescue ArgumentError, TypeError
      nil
    end

    private_class_method :annual_amount_plausible?, :infer_unit, :coerce_number, :parse_decimalish, :invalid
  end
end
