require "test_helper"

class PlaceSnapshotTest < ActiveSupport::TestCase
  DETAILS = {
    "id" => "ChIJ-ho-guom",
    "displayName" => { "text" => "Cộng Cà Phê" },
    "formattedAddress" => "35A Nguyễn Hữu Huân, Hoàn Kiếm, Hà Nội",
    "location" => { "latitude" => 21.032, "longitude" => 105.855 },
    "addressComponents" => [
      { "longText" => "Hoàn Kiếm", "types" => [ "administrative_area_level_2" ] },
      { "longText" => "Hà Nội", "types" => [ "administrative_area_level_1" ] }
    ],
    "types" => [ "cafe", "food" ]
  }.freeze

  test "chuẩn hoá details cho form" do
    attributes = Google::PlaceSnapshot.new(DETAILS).response_attributes

    assert_equal "ChIJ-ho-guom", attributes[:place_id]
    assert_equal "Cộng Cà Phê", attributes[:display_name]
    assert_equal "Hoàn Kiếm", attributes[:district]
    assert_equal "Hà Nội", attributes[:city]
    assert_equal "cafe", attributes[:place_type]
  end

  test "upsert dùng chung google place id và không ghi đè display_name đã chỉnh" do
    existing = create(:place, google_place_id: "ChIJ-ho-guom", display_name: "Tên riêng")

    place = Google::PlaceUpsert.new(details: DETAILS).call

    assert_equal existing.id, place.id
    assert_equal "Tên riêng", place.display_name
    assert_equal "Cộng Cà Phê", place.cached_name
    assert_equal "google", place.coords_source
    assert_equal DETAILS, place.cached_payload
  end
end
