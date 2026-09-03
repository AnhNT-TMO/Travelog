class CollectionsController < ApplicationController
  HOME_LIMIT = 6
  TAG_KINDS  = %w[area vibe].freeze

  def index
    @area_tags = top_tags("area")
    @vibe_tags = top_tags("vibe")
    @counts_by_tag = counts_by_tag
    @collection_covers_by_tag = collection_covers_by_tag(@area_tags + @vibe_tags)
    @group_counts = group_counts

    @untagged_places = untagged_places.with_card_data.order(:id).limit(HOME_LIMIT).to_a
  end

  def tag_group
    @kind = params[:kind].presence_in(TAG_KINDS) || TAG_KINDS.first
    @tags = tags_by_place_count(@kind)
    @counts_by_tag = counts_by_tag
    @collection_covers_by_tag = collection_covers_by_tag(@tags)
    @group_counts = group_counts
  end

  def untagged
    @user_places = untagged_places.with_card_data.order(:id).to_a
    @group_counts = group_counts
  end

  private

  def untagged_places
    scoped_places.where.missing(:taggings)
  end

  def tags_of_kind(kind)
    @sidebar_tags.select { |tag| tag.kind == kind }
  end

  def tags_by_place_count(kind)
    tags_of_kind(kind).sort_by { |tag| [ -tag.user_places_count, tag.position, tag.name ] }
  end

  def top_tags(kind)
    tags_by_place_count(kind).first(HOME_LIMIT)
  end

  def group_counts
    {
      area:     tags_of_kind("area").size,
      vibe:     tags_of_kind("vibe").size,
      untagged: untagged_places.count
    }
  end

  def counts_by_tag
    scoped_places
      .joins(:taggings)
      .group("taggings.tag_id", :status)
      .count
      .each_with_object(Hash.new { |hash, key| hash[key] = { wishlist: 0, visited: 0 } }) do |((tag_id, status), total), acc|
        acc[tag_id][status.to_sym] = total
      end
  end

  def collection_covers_by_tag(tags)
    tag_ids = tags.map(&:id)
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
