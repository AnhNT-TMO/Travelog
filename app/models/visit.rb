class Visit < ApplicationRecord
  enum :source, { manual: 0, exif_import: 1, takeout: 2 }

  belongs_to :user_place
  has_many :photos, -> { order(:position, :id) }, dependent: :nullify

  validates :visited_at, presence: true

  after_commit :sync_parent

  scope :chronological, -> { order(visited_at: :desc, id: :desc) }

  private

  def sync_parent
    parent = user_place
    return if parent.nil? || parent.destroyed?

    parent.recalc_visit_stats!
  end
end
