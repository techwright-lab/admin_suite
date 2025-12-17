# frozen_string_literal: true

# BlogPost represents a public-facing blog article managed via the custom admin panel.
#
# Content is stored as markdown-like text and rendered on the public blog pages.
class BlogPost < ApplicationRecord
  extend FriendlyId

  STATUSES = %i[draft published].freeze

  acts_as_taggable_on :tags
  has_one_attached :cover_image

  friendly_id :title, use: [ :slugged, :finders ]

  enum :status, STATUSES, default: :draft

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :body, presence: true

  scope :published_publicly, -> { published.where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :recent_first, -> { order(published_at: :desc, created_at: :desc) }

  # Generate a new slug when the title changes or when slug is blank.
  #
  # @return [Boolean]
  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_title?
  end

  # Returns true when this post should be visible publicly.
  #
  # @return [Boolean]
  def publicly_visible?
    published? && published_at.present? && published_at <= Time.current
  end

  # Returns an optimized variant for the cover image.
  #
  # @param size [Symbol] :thumbnail, :medium, :large, :og
  # @return [ActiveStorage::Variant, ActiveStorage::Attached, nil]
  def cover_image_variant(size: :medium)
    return unless cover_image.attached?

    dimensions =
      case size
      when :thumbnail then [ 400, 225 ] # 16:9
      when :medium    then [ 800, 450 ]
      when :large     then [ 1200, 675 ]
      when :og        then [ 1200, 630 ] # OpenGraph standard
      else
        nil
      end

    return cover_image if dimensions.nil?

    cover_image.variant(resize_to_fill: dimensions)
  end
end
