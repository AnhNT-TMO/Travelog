class Photo < ApplicationRecord
  belongs_to :visit, optional: true
  belongs_to :user_place
  belongs_to :user

  # Active Storage CHỈ dùng cho upload plumbing. Không gọi .variant() ở bất kỳ
  # đâu — Lambda sinh thumbnail, Rails không resize (plan §11.2).
  has_one_attached :file

  before_validation :copy_key_from_blob, on: :create
  after_create_commit :ensure_cover
  after_commit :touch_counters, on: [ :create, :destroy ]

  validates :s3_key, presence: true, uniqueness: true

  scope :ordered,  -> { order(:position, :id) }
  scope :selected, -> { where(selected_for_google: true) }

  # URL derivative gom theo user_place_id — cũng là id trên route /places/:id.
  def thumb_url(size = Photos::ThumbnailUrl::THUMB)
    Photos::ThumbnailUrl.call(s3_key, size, place_id: user_place_id)
  end

  def srcset = Photos::ThumbnailUrl.srcset(s3_key, place_id: user_place_id)

  private

  def copy_key_from_blob
    self.s3_key ||= file&.blob&.key
  end

  def ensure_cover
    user_place.update!(cover_photo_id: id) if user_place.cover_photo_id.nil?
  end

  def touch_counters
    user_place.update_columns(photos_count: user_place.photos.count)
    visit&.update_columns(photos_count: visit.photos.count)
  end
end
