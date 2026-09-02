class TakeoutCandidate < ApplicationRecord
  enum :state, { unresolved: 0, confirmed: 1, skipped: 2 }

  belongs_to :takeout_import
  belongs_to :matched_place, class_name: "Place", optional: true

  AUTO_MATCH_CONFIDENCE = 75

  scope :needing_review, -> { unresolved.order(match_confidence: :desc) }

  def auto_matchable? = matched_place_id.present? && match_confidence.to_i >= AUTO_MATCH_CONFIDENCE
end
