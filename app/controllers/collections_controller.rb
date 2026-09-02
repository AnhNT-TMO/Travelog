# Trang chủ — mockup D1 / M1.
class CollectionsController < ApplicationController
  RECENT_LIMIT = 8

  def index
    @area_tags = @sidebar_tags.select(&:area?)
    @vibe_tags = @sidebar_tags.select(&:vibe?)
    @counts_by_tag = counts_by_tag

    @recent_places = scoped_places.wishlist
                                  .with_card_data
                                  .order(created_at: :desc)
                                  .limit(RECENT_LIMIT)
  end

  private

  # { tag_id => { wishlist: n, visited: n } } trong 1 query thay vì N+1.
  def counts_by_tag
    scoped_places
      .joins(:taggings)
      .group("taggings.tag_id", :status)
      .count
      .each_with_object(Hash.new { |hash, key| hash[key] = { wishlist: 0, visited: 0 } }) do |((tag_id, status), total), acc|
        acc[tag_id][status.to_sym] = total
      end
  end
end
