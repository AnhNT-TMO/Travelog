require "test_helper"

class ReviewLinkTest < ActiveSupport::TestCase
  test "dùng writereview khi có google_place_id" do
    place = create(:place, google_place_id: "ChIJabc123")

    assert_equal "https://search.google.com/local/writereview?placeid=ChIJabc123",
                 Google::ReviewLink.for(place)
  end

  test "fallback về tìm kiếm theo tên khi chưa có google_place_id" do
    place = create(:place, display_name: "Sen Tây Hồ", google_place_id: nil)

    assert_includes Google::ReviewLink.for(place), "google.com/maps/search"
    assert_includes Google::ReviewLink.for(place), CGI.escape("Sen Tây Hồ")
  end

  test "fallback_for dùng place_id khi có" do
    place = create(:place, google_place_id: "ChIJabc123")

    assert_equal "https://www.google.com/maps/place/?q=place_id:ChIJabc123",
                 Google::ReviewLink.fallback_for(place)
  end
end
