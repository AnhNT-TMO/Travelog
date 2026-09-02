# Quanh đây — mockup D4. Server là nguồn sự thật: kéo pin trung tâm hay đổi
# slider đều submit về đây, cả danh sách lẫn pin render lại từ kết quả Postgres.
# Không lọc bằng JS phía client, nếu không số đếm sẽ lệch với pin (plan §9.5).
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

    # Nơi thiếu toạ độ không bao giờ lọt vào kết quả radius — phải nói ra
    # thay vì im lặng bỏ qua (plan §9.4).
    @missing_coords_count = @query.places_without_coords.distinct.count

    render partial: "nearby/content" if turbo_frame_request?
  end

  private

  def resolve_center
    return { lat: params[:lat], lng: params[:lng] } if params[:lat].present? && params[:lng].present?

    { lat: nil, lng: nil }
  end

  def center_name
    return params[:center_name] if params[:center_name].present?
    return t("nearby.index.custom_center") if params[:lat].present? && params[:lng].present?

    t("nearby.index.center_default")
  end
end
