require "test_helper"

class ReviewKitLinksTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @place = create(:place, display_name: "Sen Tây Hồ", google_place_id: "ChIJabc123")
    sign_in @user
  end

  test "wishlist uses one cross-platform Google Maps link without a fallback" do
    user_place = create(:user_place, user: @user, place: @place)

    get place_path(user_place)

    assert_response :success
    assert_select "a[href='#{Google::ReviewLink.maps_for(@place)}']", text: /Google Maps/, count: 1
    assert_select "a[href*='search.google.com/local/writereview']", count: 0
    assert_select "a", text: /Thử link này/, count: 0
  end

  test "visited place uses the same cross-platform Google Maps link" do
    user_place = create(:user_place, :visited, user: @user, place: @place)

    get place_path(user_place)

    assert_response :success
    assert_select "a[href='#{Google::ReviewLink.maps_for(@place)}']", text: /Google Maps/, count: 1
    assert_select "a[href*='search.google.com/local/writereview']", count: 0
  end
end
