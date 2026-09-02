module Google
  # Chuẩn hoá payload Place Details (New) thành contract nhỏ dùng chung cho
  # JSON trả về trình duyệt và bản ghi Place. Payload gốc vẫn được giữ trong
  # cached_payload theo TTL hiện có để có thể đối chiếu khi Google đổi shape.
  class PlaceSnapshot
    CAFE_TYPES = %w[cafe coffee_shop].freeze
    FOOD_TYPES = %w[restaurant food bakery bar meal_delivery meal_takeaway].freeze
    SIGHT_TYPES = %w[
      tourist_attraction museum art_gallery park place_of_worship
      historical_landmark cultural_landmark
    ].freeze
    DISTRICT_TYPES = %w[administrative_area_level_2 sublocality_level_1 sublocality].freeze
    CITY_TYPES = %w[administrative_area_level_1 locality].freeze

    attr_reader :payload

    def initialize(payload)
      @payload = payload
    end

    def google_place_id = payload.fetch("id")
    def display_name = payload.dig("displayName", "text").presence || google_place_id
    def address = payload["formattedAddress"].to_s
    def lat = payload.dig("location", "latitude")
    def lng = payload.dig("location", "longitude")
    def district = address_component(DISTRICT_TYPES)
    def city = address_component(CITY_TYPES)

    def place_type
      types = Array(payload["types"])
      return "cafe" if (types & CAFE_TYPES).any?
      return "food" if (types & FOOD_TYPES).any?
      return "sight" if (types & SIGHT_TYPES).any?

      "other"
    end

    def response_attributes
      {
        place_id: google_place_id,
        display_name: display_name,
        address: address,
        district: district,
        city: city,
        lat: lat,
        lng: lng,
        place_type: place_type
      }
    end

    def place_attributes
      {
        cached_name: display_name,
        cached_address: address,
        district: district,
        city: city,
        lat: lat,
        lng: lng,
        place_type: place_type,
        coords_source: :google,
        cached_payload: payload,
        cached_at: Time.current
      }
    end

    private

    def address_component(preferred_types)
      preferred_types.each do |type|
        component = Array(payload["addressComponents"]).find do |candidate|
          Array(candidate["types"]).include?(type)
        end
        return component["longText"].presence if component.present?
      end

      nil
    end
  end
end
