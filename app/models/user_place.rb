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

  # Form thêm/sửa địa điểm nhập tay tạo cả Place lẫn UserPlace trong một lượt
  # submit. Khi Google autocomplete lên, place_id có sẵn sẽ được gán thay vì
  # tạo mới.
  accepts_nested_attributes_for :place

  validates :place_id, uniqueness: { scope: :user_id }
  validates :my_rating, inclusion: { in: 1..5 }, allow_nil: true

  # tên hiển thị: tên tôi đặt > tên canonical
  def label = nickname.presence || place.display_name

  scope :for_state, ->(state) {
    case state.to_s
    when "wishlist" then wishlist
    when "visited"  then visited
    else all
    end
  }

  # AND chứ không phải OR: chọn "chill" + "rooftop" = chỗ có CẢ HAI tag.
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

  # Tạo Photo từ signed id mà direct upload trả về. Ảnh đã nằm trên S3 rồi;
  # việc còn lại chỉ là gắn blob và chép metadata xuống cột của mình.
  #
  # find_signed! chứ không find_signed: signed id sai hoặc bị sửa phải nổ ra
  # RecordNotFound, đừng âm thầm bỏ qua rồi báo "đã thêm ảnh" cho một ảnh
  # không tồn tại.
  def attach_photos!(signed_ids, user:, visit: nil)
    Array(signed_ids).reject(&:blank?).each_with_index.map do |signed_id, index|
      blob = ActiveStorage::Blob.find_signed!(signed_id)
      raise ActiveRecord::RecordNotFound unless blob.key.start_with?("#{id}/")

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

  # gọi từ callback của Visit — giữ denormalized counters đúng.
  # Luôn destroy chứ đừng delete_all, nếu không counters lệch (plan §19.15).
  def recalc_visit_stats!
    update!(
      visits_count:     visits.count,
      first_visited_at: visits.minimum(:visited_at),
      last_visited_at:  visits.maximum(:visited_at),
      status:           visits.any? ? :visited : status
    )
  end
end
