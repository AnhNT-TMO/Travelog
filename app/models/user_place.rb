class UserPlace < ApplicationRecord
  enum :status,              { wishlist: 0, visited: 1 }
  enum :google_review_state, { unknown: 0, not_reviewed: 1, reviewed: 2 }, prefix: :review

  belongs_to :user
  belongs_to :place
  belongs_to :cover_photo, class_name: "Photo", optional: true

  has_many :visits,   dependent: :destroy
  has_many :photos,   dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  accepts_nested_attributes_for :place

  validates :place_id, uniqueness: { scope: :user_id }
  validates :my_rating, inclusion: { in: 1..5 }, allow_nil: true
  validate :status_matches_visits, if: :will_save_change_to_status?

  def label = nickname.presence || place.display_name

  scope :for_state, ->(state) {
    case state.to_s
    when "wishlist" then wishlist
    when "visited"  then visited
    else all
    end
  }

  scope :tagged_with_all, ->(tag_ids) {
    ids = Array(tag_ids).reject(&:blank?)
    next all if ids.empty?

    matching_ids = Tagging.where(tag_id: ids)
                          .group(:user_place_id)
                          .having("COUNT(DISTINCT taggings.tag_id) = ?", ids.size)
                          .select(:user_place_id)

    where(id: matching_ids)
  }

  scope :with_card_data, -> {
    includes(:place, :tags, cover_photo: { file_attachment: :blob })
  }

  def attach_photos!(signed_ids, user:, visit: nil)
    blobs = Array(signed_ids).reject(&:blank?).map do |signed_id|
      ActiveStorage::Blob.find_signed!(signed_id)
    end

    blobs.each do |blob|
      raise ActiveRecord::RecordNotFound unless blob.key.start_with?("#{id}/")
    end

    transaction do
      blobs.each_with_index.map do |blob, index|
        photo = photos.create!(
          user:         user,
          visit:        visit,
          position:     photos_count + index,
          s3_key:       blob.key,
          content_type: blob.content_type,
          byte_size:    blob.byte_size
        )
        photo.file.attach(blob)
        photo
      end
    end
  end

  def recalc_visit_stats!
    count, first_visited_at, last_visited_at = visits.unscope(:order).pick(
      Arel.sql("COUNT(*)::integer"),
      Arel.sql("MIN(visited_at)"),
      Arel.sql("MAX(visited_at)")
    )

    update!(
      visits_count:     count,
      first_visited_at: first_visited_at,
      last_visited_at:  last_visited_at,
      status:           count.positive? ? :visited : :wishlist
    )
  end

  private

  def status_matches_visits
    expected_status = visits.exists? ? "visited" : "wishlist"
    errors.add(:status, :invalid) unless status == expected_status
  end
end
