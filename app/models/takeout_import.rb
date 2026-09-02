class TakeoutImport < ApplicationRecord
  enum :state, { pending: 0, parsing: 1, needs_review: 2, done: 3, failed: 4 }

  belongs_to :user
  has_many :takeout_candidates, dependent: :destroy
  has_one_attached :file

  scope :recent, -> { order(created_at: :desc) }
end
