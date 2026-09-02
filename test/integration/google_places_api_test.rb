require "test_helper"

class GooglePlacesApiTest < ActionDispatch::IntegrationTest
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

  test "autocomplete trả contract nhỏ từ backend" do
    client = Object.new
    client.define_singleton_method(:autocomplete) do |_input, **_options|
      {
        "suggestions" => [
          {
            "placePrediction" => {
              "placeId" => "ChIJ123",
              "text" => { "text" => "Hồ Gươm, Hà Nội" },
              "structuredFormat" => {
                "mainText" => { "text" => "Hồ Gươm" },
                "secondaryText" => { "text" => "Hoàn Kiếm, Hà Nội" }
              }
            }
          }
        ]
      }
    end

    with_stubbed_method(Google::PlacesClient, :new, -> { client }) do
      get api_places_autocomplete_path,
          params: { q: "Hồ Gươm", session_token: SecureRandom.uuid, lat: 21.0, lng: 105.8 }
    end

    assert_response :success
    body = response.parsed_body
    assert_equal "ChIJ123", body.dig("suggestions", 0, "place_id")
    assert_equal "Hồ Gươm", body.dig("suggestions", 0, "main_text")
  end

  test "details dùng cùng session token và trả field cho cả form lẫn nearby" do
    received_token = nil
    client = Object.new
    client.define_singleton_method(:details) do |_place_id, session_token:|
      received_token = session_token
      DETAILS
    end
    token = SecureRandom.uuid

    with_stubbed_method(Google::PlacesClient, :new, -> { client }) do
      get api_places_details_path, params: { place_id: "ChIJ-ho-guom", session_token: token }
    end

    assert_response :success
    assert_equal token, received_token
    assert_equal 21.032, response.parsed_body["lat"]
    assert_equal "Hoàn Kiếm", response.parsed_body["district"]
  end

  test "autocomplete yêu cầu đăng nhập" do
    sign_out @user

    get api_places_autocomplete_path,
        params: { q: "Hồ Gươm", session_token: SecureRandom.uuid }

    assert_redirected_to new_user_session_path
  end
end
