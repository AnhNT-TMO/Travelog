require "test_helper"

class PlacesAutocompleteCreateTest < ActionDispatch::IntegrationTest
  DETAILS = {
    "id" => "ChIJ-ho-guom",
    "displayName" => { "text" => "Cộng Cà Phê" },
    "formattedAddress" => "35A Nguyễn Hữu Huân, Hoàn Kiếm, Hà Nội",
    "location" => { "latitude" => 21.032, "longitude" => 105.855 },
    "addressComponents" => [
      { "longText" => "Hoàn Kiếm", "types" => [ "administrative_area_level_2" ] },
      { "longText" => "Hà Nội", "types" => [ "administrative_area_level_1" ] }
    ],
    "types" => [ "cafe" ]
  }.freeze

  setup do
    @user = create(:user)
    sign_in @user
  end

  test "create lấy details đã cache ở backend và gắn Place dedupe theo Google id" do
    client = Object.new
    client.define_singleton_method(:details) { |_place_id| DETAILS }

    with_stubbed_method(Google::PlacesClient, :new, -> { client }) do
      post places_path, params: {
        user_place: {
          status: "wishlist",
          place_attributes: {
            google_place_id: "ChIJ-ho-guom",
            display_name: "Giá trị từ browser không được tin cậy"
          }
        }
      }
    end

    user_place = @user.user_places.last
    assert_redirected_to place_path(user_place)
    assert_equal "ChIJ-ho-guom", user_place.place.google_place_id
    assert_equal "Cộng Cà Phê", user_place.place.display_name
    assert_equal "Hoàn Kiếm", user_place.place.district
    assert_equal "google", user_place.place.coords_source
  end

  test "Google lỗi thì render lại form với dữ liệu đã nhập thay vì lưu nhầm Place" do
    client = Object.new
    client.define_singleton_method(:details) do |_place_id|
      raise Google::PlacesError, "timeout"
    end

    with_stubbed_method(Google::PlacesClient, :new, -> { client }) do
      post places_path, params: {
        user_place: {
          status: "wishlist",
          place_attributes: {
            google_place_id: "ChIJ-timeout",
            display_name: "Tên đang nhập",
            cached_address: "Hoàn Kiếm, Hà Nội"
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "input[name='user_place[place_attributes][display_name]'][value='Tên đang nhập']"
    assert_equal 0, @user.user_places.count
  end
end
