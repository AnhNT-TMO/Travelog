class Place < ApplicationRecord
  enum :place_type,    { cafe: 0, food: 1, sight: 2, other: 3 }
  enum :coords_source, { google: 0, exif: 1, manual: 2 }, prefix: :coords_from

  has_many :user_places, dependent: :restrict_with_error

  # Nhập tay thì toạ độ là do người dùng gõ, không phải của Google — ghi đúng
  # nguồn để sau này biết cái nào cần đối chiếu lại.
  before_validation :mark_manual_coords, on: :create

  validates :display_name, presence: true
  validates :google_place_id, uniqueness: true, allow_nil: true
  validates :lat, :lng, numericality: true, allow_nil: true

  scope :with_coords, -> { where.not(lat: nil).where.not(lng: nil) }

  # Radius filter — plan §9. KHÔNG viết SQL radius rải rác ở chỗ khác, chỉ dùng
  # scope này (hoặc Geo::RadiusQuery bọc ngoài nó).
  # earth_box dùng được index gist nên lọc thô trước, earth_distance lọc chính xác sau.
  scope :within_radius, ->(lat, lng, meters) {
    with_coords.where(
      sanitize_sql_array([
        "earth_box(ll_to_earth(?, ?), ?) @> ll_to_earth(places.lat, places.lng) " \
        "AND earth_distance(ll_to_earth(?, ?), ll_to_earth(places.lat, places.lng)) <= ?",
        lat, lng, meters, lat, lng, meters
      ])
    )
  }

  # Phải gọi trước khi ORDER BY distance_m, nếu không Postgres lỗi khi có .distinct
  # (plan §19.3).
  scope :select_distance_from, ->(lat, lng) {
    select(sanitize_sql_array([
      "places.*, earth_distance(ll_to_earth(?, ?), ll_to_earth(places.lat, places.lng)) AS distance_m",
      lat, lng
    ]))
  }

  # Tìm theo tên tiếng Việt không dấu — khớp đúng biểu thức của
  # index_places_on_display_name_trgm, nếu lệch thì Postgres bỏ index (plan §19.13).
  scope :name_matching, ->(query) {
    term = query.to_s.strip
    next all if term.blank?

    where(
      sanitize_sql_array([
        "lower(immutable_unaccent(places.display_name)) LIKE lower(immutable_unaccent(?))",
        "%#{term}%"
      ])
    )
  }

  def coordinates? = lat.present? && lng.present?

  # Cache Maps Content quá 30 ngày là vi phạm điều khoản (plan §10.4).
  def cache_stale? = cached_at.nil? || cached_at < 30.days.ago

  private

  def mark_manual_coords
    self.coords_source = :manual if google_place_id.blank?
  end
end
