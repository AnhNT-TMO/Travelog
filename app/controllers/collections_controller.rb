class CollectionsController < ApplicationController
  RECENT_LIMIT = 8

  def index
    @area_tags = @sidebar_tags.select(&:area?)
    @vibe_tags = @sidebar_tags.select(&:vibe?)
    @counts_by_tag = counts_by_tag
    @collection_covers_by_tag = collection_covers_by_tag

    @recent_places = scoped_places.wishlist
                                  .with_card_data
                                  .order(created_at: :desc)
                                  .limit(RECENT_LIMIT)
  end

  private

  def counts_by_tag
    scoped_places
      .joins(:taggings)
      .group("taggings.tag_id", :status)
      .count
      .each_with_object(Hash.new { |hash, key| hash[key] = { wishlist: 0, visited: 0 } }) do |((tag_id, status), total), acc|
        acc[tag_id][status.to_sym] = total
      end
  end

  def collection_covers_by_tag
    tag_ids = (@area_tags + @vibe_tags).map(&:id)
    return {} if tag_ids.empty?

    scoped_places
      .joins(:taggings)
      .where(taggings: { tag_id: tag_ids })
      .where.not(cover_photo_id: nil)
      .select("DISTINCT ON (taggings.tag_id) user_places.*, taggings.tag_id AS collection_tag_id")
      .order(Arel.sql("taggings.tag_id, user_places.created_at DESC, user_places.id DESC"))
      .includes(cover_photo: { file_attachment: :blob })
      .index_by { |user_place| user_place[:collection_tag_id] }
  end
end
