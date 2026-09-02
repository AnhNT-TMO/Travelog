require "test_helper"

# Radius filter là chỗ dễ sai nhất của app này (plan §18.1) — toạ độ dưới đây
# là toạ độ thật, khoảng cách trong assert là khoảng cách thật.
class PlaceTest < ActiveSupport::TestCase
  PHU_TAY_HO = { lat: 21.0587, lng: 105.8194 }.freeze

  setup do
    # ~180m từ Phủ Tây Hồ
    @very_near = create(:place, display_name: "Sen Tây Hồ", lat: 21.0600, lng: 105.8205)
    # ~1.2km
    @near      = create(:place, display_name: "Nhà Sàn", lat: 21.0680, lng: 105.8230)
    # ~1.7km
    @edge      = create(:place, display_name: "Bờ Kè", lat: 21.0730, lng: 105.8180)
    # ~6km — ngoài bán kính
    @far       = create(:place, display_name: "Phở Bát Đàn", lat: 21.0345, lng: 105.8470)
    # không có toạ độ — phải bị loại, không được raise
    @no_coords = create(:place, display_name: "Quán nhập tay", lat: nil, lng: nil)
  end

  test "within_radius chỉ trả về nơi nằm trong bán kính" do
    found = Place.within_radius(PHU_TAY_HO[:lat], PHU_TAY_HO[:lng], 1_800)

    assert_equal [ @very_near, @near, @edge ].map(&:id).sort, found.map(&:id).sort
  end

  test "within_radius loại nơi ngoài bán kính" do
    found = Place.within_radius(PHU_TAY_HO[:lat], PHU_TAY_HO[:lng], 1_800)

    assert_not_includes found.map(&:id), @far.id
  end

  test "within_radius bỏ qua nơi thiếu lat hoặc lng, không raise" do
    found = Place.within_radius(PHU_TAY_HO[:lat], PHU_TAY_HO[:lng], 50_000)

    assert_not_includes found.map(&:id), @no_coords.id
    assert_includes found.map(&:id), @far.id
  end

  test "bán kính nhỏ chỉ giữ lại nơi rất gần" do
    found = Place.within_radius(PHU_TAY_HO[:lat], PHU_TAY_HO[:lng], 400)

    assert_equal [ @very_near.id ], found.map(&:id)
  end

  test "select_distance_from trả về distance_m tính bằng mét" do
    place = Place.select_distance_from(PHU_TAY_HO[:lat], PHU_TAY_HO[:lng]).find(@very_near.id)

    assert_in_delta 180, place[:distance_m], 60
  end

  test "name_matching khớp tên tiếng Việt không dấu" do
    assert_includes Place.name_matching("sen tay ho").map(&:id), @very_near.id
    assert_includes Place.name_matching("Sen Tây Hồ").map(&:id), @very_near.id
  end
end
