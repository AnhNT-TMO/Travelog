require "test_helper"

class NearbyTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    create(:user_place, user: @user, place: create(:place, lat: 21.0287, lng: 105.8524))
    sign_in @user
  end

  test "vào nearby không có params luôn trở về tâm Hồ Gươm" do
    get nearby_path, params: { lat: 20.99, lng: 105.95, center_name: "Vị trí hiện tại" }
    assert_response :success

    get nearby_path

    assert_response :success
    assert_select "input[name='lat'][value='#{Geo::RadiusQuery::DEFAULT_LAT}']"
    assert_select "input[name='lng'][value='#{Geo::RadiusQuery::DEFAULT_LNG}']"
    assert_select "input[name='center_name'][value='Hồ Gươm (mặc định)']"
  end

  test "Turbo radius response thay toàn bộ map và label trong cùng frame" do
    get nearby_path,
        params: { lat: 21.0287, lng: 105.8524, radius: 5_700, state: "all" },
        headers: { "Turbo-Frame" => "nearby_content" }

    assert_response :success
    assert_select "turbo-frame#nearby_content"
    assert_select "[data-nearby-map-radius-value='5700']"
    assert_select "h3", text: /5[,.]7 km/
    assert_select "form[data-turbo-frame='nearby_content']"
  end
end
