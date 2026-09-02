require "test_helper"

class RadiusQueryTest < ActiveSupport::TestCase
  PHU_TAY_HO = { lat: 21.0587, lng: 105.8194 }.freeze

  setup do
    @user  = create(:user)
    @other = create(:user)

    @near = create(:user_place, user: @user, status: :wishlist,
                   place: create(:place, lat: 21.0600, lng: 105.8205))
    @near_visited = create(:user_place, user: @user, status: :visited,
                           place: create(:place, lat: 21.0680, lng: 105.8230))
    @far = create(:user_place, user: @user,
                  place: create(:place, lat: 21.0345, lng: 105.8470))
    @no_coords = create(:user_place, user: @user,
                        place: create(:place, lat: nil, lng: nil))

    # Của người khác — không bao giờ được lọt vào kết quả.
    @foreign = create(:user_place, user: @other,
                      place: create(:place, lat: 21.0601, lng: 105.8206))
  end

  test "chỉ trả về user_places của chính user" do
    ids = query.call.map(&:id)

    assert_not_includes ids, @foreign.id
    assert_includes ids, @near.id
  end

  test "sắp xếp tăng dần theo khoảng cách và có distance_m" do
    results = query(radius_m: 3_000).call.to_a

    assert_equal [ @near.id, @near_visited.id ], results.map(&:id)
    assert results.first[:distance_m] < results.last[:distance_m]
  end

  test "state lọc đúng và counts khớp" do
    assert_equal [ @near.id ], query(radius_m: 3_000, state: "wishlist").call.map(&:id)
    assert_equal({ wishlist: 1, visited: 1, all: 2 }, query(radius_m: 3_000).counts)
  end

  test "radius bị clamp vào khoảng cho phép" do
    assert_equal Geo::RadiusQuery::MIN_RADIUS_M, query(radius_m: 1).radius_m
    assert_equal Geo::RadiusQuery::MAX_RADIUS_M, query(radius_m: 999_999).radius_m
  end

  test "nơi thiếu toạ độ được đếm riêng để cảnh báo" do
    assert_equal 1, query.places_without_coords.distinct.count
  end

  test "map_points chỉ serialize id lat lng name status" do
    point = query.map_points([ @near ]).first

    assert_equal %i[id lat lng name status].sort, point.keys.sort
  end

  private

  def query(radius_m: 1_800, state: "all", tag_ids: [])
    Geo::RadiusQuery.new(user: @user, lat: PHU_TAY_HO[:lat], lng: PHU_TAY_HO[:lng],
                         radius_m: radius_m, state: state, tag_ids: tag_ids)
  end
end
