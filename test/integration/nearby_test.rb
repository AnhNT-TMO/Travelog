require "test_helper"

class NearbyTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    create(:user_place, user: @user, place: create(:place, lat: 21.0287, lng: 105.8524))
    sign_in @user
  end

  test "lần đầu vào nearby thì bật auto-locate và rơi về Hồ Gươm trong lúc chờ" do
    get nearby_path

    assert_response :success
    assert_select "input[name='lat'][value='#{Geo::RadiusQuery::DEFAULT_LAT}']"
    assert_select "input[name='lng'][value='#{Geo::RadiusQuery::DEFAULT_LNG}']"
    assert_select "input[name='center_name'][value='Hồ Gươm (dự phòng)']"
    assert_select "form[data-geolocate-auto-value='true']"
  end

  test "bán kính mặc định là 3 km" do
    get nearby_path

    assert_response :success
    assert_select "input[name='radius'][value='3000']"
    assert_select "[data-nearby-map-radius-value='3000']"
  end

  test "tâm vừa dùng được nhớ lại nên không auto-locate lần nữa" do
    get nearby_path, params: { lat: 20.99, lng: 105.95, center_name: "Vị trí hiện tại" }
    assert_response :success

    get nearby_path

    assert_response :success
    assert_select "input[name='lat'][value='20.99']"
    assert_select "input[name='lng'][value='105.95']"
    assert_select "input[name='center_name'][value='Vị trí hiện tại']"
    assert_select "form[data-geolocate-auto-value='false']"
  end

  test "tâm đã nhớ quá CENTER_TTL thì bỏ qua và auto-locate lại" do
    get nearby_path, params: { lat: 20.99, lng: 105.95, center_name: "Vị trí hiện tại" }
    assert_response :success

    travel (NearbyController::CENTER_TTL + 1.minute) do
      get nearby_path

      assert_response :success
      assert_select "input[name='lat'][value='#{Geo::RadiusQuery::DEFAULT_LAT}']"
      assert_select "form[data-geolocate-auto-value='true']"
    end
  end

  test "canvas của map là permanent element nên Turbo giữ lại object Map qua mỗi lần render frame" do
    get nearby_path

    assert_response :success
    assert_select "#nearby_map_canvas[data-turbo-permanent]"
    assert_select "#nearby_map_canvas[data-nearby-map-target='canvas']"
  end

  test "Turbo radius response giữ nguyên id permanent của canvas" do
    get nearby_path,
        params: { lat: 21.0287, lng: 105.8524, radius: 5_700, state: "all" },
        headers: { "Turbo-Frame" => "nearby_content" }

    assert_response :success
    assert_select "#nearby_map_canvas[data-turbo-permanent]"
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
