class Tagging < ApplicationRecord
  belongs_to :tag, counter_cache: :user_places_count
  belongs_to :user_place

  validates :tag_id, uniqueness: { scope: :user_place_id }
end
