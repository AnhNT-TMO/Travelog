class Visit < ApplicationRecord
  enum :source, { manual: 0, exif_import: 1 }

  belongs_to :user_place
  has_many :photos, dependent: :nullify

  validates :visited_at, presence: true

  after_commit :sync_parent

  scope :chronological, -> { order(visited_at: :desc) }

  private

  def sync_parent = user_place.recalc_visit_stats!
end
