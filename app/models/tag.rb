class Tag < ApplicationRecord
  enum :kind,       { area: 0, vibe: 1, free: 2 }
  enum :visibility, { private_only: 0, unlisted: 1 }, prefix: :share

  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :user_places, through: :taggings

  before_validation :set_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(:kind, :position, :name) }

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

  def set_slug
    self.slug = slug.presence || Vietnamese.slugify(name)
  end
end
