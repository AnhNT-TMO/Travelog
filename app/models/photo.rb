class Photo < ApplicationRecord
  belongs_to :visit, optional: true
  belongs_to :user_place
  belongs_to :user

  has_one_attached :file

  before_validation :copy_key_from_blob, on: :create
  after_create_commit :ensure_cover
  after_commit :touch_counters, on: [ :create, :destroy ]

  validates :s3_key, presence: true, uniqueness: true

  scope :ordered,  -> { order(:position, :id) }
  scope :selected, -> { where(selected_for_google: true) }

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
    sync_photos_count(user_place)
    sync_photos_count(visit)
  end

  def sync_photos_count(record)
    return if record.nil? || record.destroyed?

    record.update_columns(photos_count: record.photos.count)
  end
end
