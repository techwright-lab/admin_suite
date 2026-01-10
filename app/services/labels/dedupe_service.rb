# frozen_string_literal: true

# Service for de-duplicating "label" style lists (e.g., strengths, domains) where the
# source may contain near-duplicates (punctuation/wording differences).
#
# We intentionally keep this conservative: it groups items only when they have
# very high token overlap, so we don't accidentally merge distinct concepts.
#
# @example
#   groups = Labels::DedupeService.new(labels, similarity_threshold: 0.82).grouped_counts
#   # => { "ruby rails backend" => { label: "Ruby on Rails backend development", count: 2 } }
#
class Labels::DedupeService
  # @param labels [Array<String>]
  # @param similarity_threshold [Float] Jaccard similarity threshold for grouping
  # @param overlap_threshold [Float] overlap/min_size threshold (helps group "A + one word" variants)
  def initialize(labels, similarity_threshold: 0.85, overlap_threshold: 0.75)
    @labels = Array(labels)
    @similarity_threshold = similarity_threshold.to_f
    @overlap_threshold = overlap_threshold.to_f
  end

  # Returns labels de-duplicated into representative strings.
  #
  # @return [Array<String>]
  def run
    grouped_counts.values.map { |h| h[:label] }
  end

  # Returns grouped counts keyed by a normalized key.
  #
  # @return [Hash{String => Hash}] e.g. { "system design" => { label: "System Design", count: 2 } }
  def grouped_counts
    groups = []

    normalized_labels.each do |label|
      tokens = tokens_for(label)
      next if tokens.empty?

      best = best_group_for(groups, tokens)
      if best
        best[:count] += 1
        best[:candidates] << label
        best[:label] = pick_representative(best[:candidates])
        next
      end

      groups << {
        key: normalize_key(label),
        tokens: tokens,
        candidates: [label],
        label: label,
        count: 1
      }
    end

    groups.each_with_object({}) do |g, acc|
      acc[g[:key]] = { label: g[:label], count: g[:count] }
    end
  end

  private

  attr_reader :labels, :similarity_threshold, :overlap_threshold

  def normalized_labels
    labels.map { |l| l.to_s.strip }.reject(&:blank?)
  end

  # Produces a stable normalized key for a label (for exact-ish matching).
  #
  # @param label [String]
  # @return [String]
  def normalize_key(label)
    s = ActiveSupport::Inflector.transliterate(label.to_s)
    s = s.downcase
    s = s.tr("&", "and")
    s = s.gsub(/[^a-z0-9\s]/, " ")
    s = s.gsub(/\s+/, " ").strip
    s
  end

  STOPWORDS = %w[
    and or the a an to of for in on with across over into at from by
  ].freeze

  # @param label [String]
  # @return [Array<String>]
  def tokens_for(label)
    normalize_key(label).split(" ").reject { |t| t.blank? || STOPWORDS.include?(t) }.uniq
  end

  def best_group_for(groups, tokens)
    best = nil
    best_score = 0.0

    groups.each do |g|
      score = similarity(g[:tokens], tokens)
      overlap = overlap_ratio(g[:tokens], tokens)

      matches = score >= similarity_threshold || (overlap >= overlap_threshold && intersection_size(g[:tokens], tokens) >= 3)
      next unless matches

      if score > best_score
        best_score = score
        best = g
      end
    end

    best
  end

  def intersection_size(a, b)
    (a & b).size
  end

  def similarity(a, b)
    return 0.0 if a.empty? || b.empty?

    inter = intersection_size(a, b)
    union = (a | b).size
    union.positive? ? (inter.to_f / union) : 0.0
  end

  def overlap_ratio(a, b)
    return 0.0 if a.empty? || b.empty?

    inter = intersection_size(a, b)
    min_size = [a.size, b.size].min
    min_size.positive? ? (inter.to_f / min_size) : 0.0
  end

  def pick_representative(candidates)
    # Prefer the shortest non-trivial label (usually more readable).
    candidates
      .map { |c| c.to_s.strip }
      .reject(&:blank?)
      .min_by { |c| [c.length, c] }
  end
end

