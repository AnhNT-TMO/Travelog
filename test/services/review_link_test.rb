require "test_helper"

class ReviewLinkTest < ActiveSupport::TestCase
  test "maps_for dùng Maps URL đa nền tảng và place id khi có" do
    place = create(:place, display_name: "Sen Tây Hồ", cached_address: "Tây Hồ, Hà Nội",
                           google_place_id: "ChIJabc123")

    assert_equal "https://www.google.com/maps/search/?api=1&query=Sen+T%C3%A2y+H%E1%BB%93%2C+T%C3%A2y+H%E1%BB%93%2C+H%C3%A0+N%E1%BB%99i&query_place_id=ChIJabc123",
                 Google::ReviewLink.maps_for(place)
  end

  test "maps_for tìm theo tên khi chưa có google_place_id" do
    place = create(:place, display_name: "Sen Tây Hồ", google_place_id: nil)

    assert_includes Google::ReviewLink.maps_for(place), "google.com/maps/search"
    assert_includes Google::ReviewLink.maps_for(place), CGI.escape("Sen Tây Hồ")
  end

  test "directions_for dùng destination_place_id khi có" do
    place = create(:place, google_place_id: "ChIJabc123")

    assert_equal "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(place.display_name)}&destination_place_id=ChIJabc123",
                 Google::ReviewLink.directions_for(place)
  end
end
