# frozen_string_literal: true

module AdminSuite
  module ThemePalette
    # Minimal Tailwind-like palette values (hex) for theming.
    # We only include the shades AdminSuite uses.
    COLORS = {
      "slate" => { 100 => "#f1f5f9", 200 => "#e2e8f0", 500 => "#64748b", 600 => "#475569", 700 => "#334155", 800 => "#1e293b", 900 => "#0f172a" },
      "indigo" => { 100 => "#e0e7ff", 200 => "#c7d2fe", 500 => "#6366f1", 600 => "#4f46e5", 700 => "#4338ca", 800 => "#3730a3", 900 => "#312e81" },
      "purple" => { 100 => "#f3e8ff", 200 => "#e9d5ff", 500 => "#a855f7", 600 => "#9333ea", 700 => "#7e22ce", 800 => "#6b21a8", 900 => "#581c87" },
      "violet" => { 100 => "#ede9fe", 200 => "#ddd6fe", 500 => "#8b5cf6", 600 => "#7c3aed", 700 => "#6d28d9", 800 => "#5b21b6", 900 => "#4c1d95" },
      "amber" => { 100 => "#fef3c7", 200 => "#fde68a", 500 => "#f59e0b", 600 => "#d97706", 700 => "#b45309", 800 => "#92400e", 900 => "#78350f" },
      "emerald" => { 100 => "#d1fae5", 200 => "#a7f3d0", 500 => "#10b981", 600 => "#059669", 700 => "#047857", 800 => "#065f46", 900 => "#064e3b" },
      "cyan" => { 100 => "#cffafe", 200 => "#a5f3fc", 500 => "#06b6d4", 600 => "#0891b2", 700 => "#0e7490", 800 => "#155e75", 900 => "#164e63" },
      "blue" => { 100 => "#dbeafe", 200 => "#bfdbfe", 500 => "#3b82f6", 600 => "#2563eb", 700 => "#1d4ed8", 800 => "#1e40af", 900 => "#1e3a8a" },
      "green" => { 100 => "#dcfce7", 200 => "#bbf7d0", 500 => "#22c55e", 600 => "#16a34a", 700 => "#15803d", 800 => "#166534", 900 => "#14532d" },
      "red" => { 100 => "#fee2e2", 200 => "#fecaca", 500 => "#ef4444", 600 => "#dc2626", 700 => "#b91c1c", 800 => "#991b1b", 900 => "#7f1d1d" }
    }.freeze

    def self.resolve(color_name, shade, fallback: nil)
      return fallback if color_name.blank?

      name = color_name.to_s.delete_prefix(":")
      COLORS.dig(name, shade) || fallback
    end

    def self.normalize_color(value, default_name:)
      return default_name.to_s if value.blank?
      value.to_s.delete_prefix(":")
    end

    def self.hex?(value)
      value.is_a?(String) && value.match?(/\A#(?:[0-9a-fA-F]{3}){1,2}\z/)
    end
  end
end
