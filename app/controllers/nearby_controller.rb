class NearbyController < ApplicationController
  CENTER_TTL = 30.minutes

  def index
    center = resolve_center
    @state = params[:state].presence_in(TagsController::STATES) || "all"
    @filter_tags = scoped_tags.where(id: Array(params[:vibe])).ordered.to_a

    @query = Geo::RadiusQuery.new(
      user:     current_user,
      lat:      center[:lat],
      lng:      center[:lng],
      radius_m: params[:radius].presence || Geo::RadiusQuery::DEFAULT_RADIUS_M,
      state:    @state,
      tag_ids:  @filter_tags.map(&:id)
    )

    @lat, @lng, @radius_m = @query.lat, @query.lng, @query.radius_m
    @center_name = center[:name]
    @auto_locate = center[:auto_locate]
    @user_places = @query.call.to_a
    @counts      = @query.counts
    @map_points  = @query.map_points(@user_places)
    @band_points = @query.band_points

    remember_nearby_center(@lat, @lng, @center_name) if explicit_center?

    render partial: "nearby/content" if turbo_frame_request?
  end

  private

  def resolve_center
    return center_from_params if explicit_center?

    remembered_center || center_to_locate
  end

  def explicit_center?
    params[:lat].present? && params[:lng].present?
  end

  def center_from_params
    {
      lat:         params[:lat],
      lng:         params[:lng],
      name:        params[:center_name].presence || t("nearby.index.custom_center"),
      auto_locate: false
    }
  end

  def remembered_center
    remembered = nearby_center
    return if remembered.blank?
    return if remembered["at"].to_i < CENTER_TTL.ago.to_i

    {
      lat:         remembered["lat"],
      lng:         remembered["lng"],
      name:        remembered["name"].presence || t("nearby.index.custom_center"),
      auto_locate: false
    }
  end

  def center_to_locate
    { lat: nil, lng: nil, name: t("nearby.index.center_default"), auto_locate: true }
  end
end
