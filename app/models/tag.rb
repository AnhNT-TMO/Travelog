class Tag < ApplicationRecord
  enum :visibility, { private_only: 0, unlisted: 1 }, prefix: :share

  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :user_places, through: :taggings

  before_validation :normalize_name
  before_validation :set_slug

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :slug, presence: true, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(:position, :name) }

  def to_param = slug

  def shared? = share_unlisted? && public_token.present?

  def enable_sharing!(share_notes: false)
    update!(
      visibility:   :unlisted,
      public_token: SecureRandom.urlsafe_base64(16),
      share_notes:  share_notes,
      shared_at:    Time.current
    )
  end

  def disable_sharing!
    update!(visibility: :private_only, public_token: nil, shared_at: nil)
  end

  private

  def normalize_name
    self.name = name.squish if name.is_a?(String)
  end

  def set_slug
    return if slug.present?

    base      = Vietnamese.slugify(name).presence || "tag"
    candidate = base
    counter   = 2

    while slug_taken?(candidate)
      candidate = "#{base}-#{counter}"
      counter  += 1
    end

    self.slug = candidate
  end

  def slug_taken?(candidate)
    Tag.where(user_id: user_id, slug: candidate).where.not(id: id).exists?
  end
end
