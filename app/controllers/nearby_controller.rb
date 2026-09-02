class NearbyController < ApplicationController
  def index
    center = resolve_center
    @state = params[:state].presence_in(TagsController::STATES) || "all"

    @query = Geo::RadiusQuery.new(
      user:     current_user,
      lat:      center[:lat],
      lng:      center[:lng],
      radius_m: params[:radius].presence || Geo::RadiusQuery::DEFAULT_RADIUS_M,
      state:    @state,
      tag_ids:  Array(params[:vibe])
    )

    @lat, @lng, @radius_m = @query.lat, @query.lng, @query.radius_m
    @center_name = center_name
    @user_places = @query.call.to_a
    @counts      = @query.counts
    @map_points  = @query.map_points(@user_places)

    @missing_coords_count = @query.places_without_coords.distinct.count

    remember_nearby_center(@lat, @lng) if explicit_center?

    render partial: "nearby/content" if turbo_frame_request?
  end

  private

  def resolve_center
    return { lat: params[:lat], lng: params[:lng] } if explicit_center?

    { lat: nil, lng: nil }
  end

  def explicit_center?
    params[:lat].present? && params[:lng].present?
  end

  def center_name
    return params[:center_name] if params[:center_name].present?
    return t("nearby.index.custom_center") if explicit_center?

    t("nearby.index.center_default")
  end
end
