require "cgi"
require "net/http"

module Google
  # Places LUÔN gọi từ server. Không nhúng key này vào JS — nó restrict theo IP
  # của EC2. Key cho Maps JS ở browser là GOOGLE_MAPS_BROWSER_KEY, hai key riêng
  # biệt (plan §9.5, §10.1).
  class PlacesClient
    BASE = "https://places.googleapis.com/v1".freeze

    # Field mask hẹp — rating/reviews/photos/openingHours thuộc SKU Enterprise,
    # đắt hơn nhiều lần (plan §10.1). Đừng thêm field vào đây mà không kiểm giá.
    DETAILS_MASK = "id,displayName,formattedAddress,location,addressComponents,types".freeze

    AUTOCOMPLETE_MASK = "suggestions.placePrediction.placeId," \
                        "suggestions.placePrediction.text," \
                        "suggestions.placePrediction.structuredFormat".freeze

    TIMEOUT_S = 5
    CACHE_TTL = 14.days

    # Hà Nội — bias mặc định cho autocomplete
    DEFAULT_LAT = 21.0278
    DEFAULT_LNG = 105.8342
    DEFAULT_BIAS_RADIUS_M = 30_000

    def initialize(api_key: Rails.application.config.settings.google.places_api_key)
      @api_key = api_key
    end

    # session_token phải dùng LẠI cho lần details tiếp theo trong cùng session,
    # khi đó phần autocomplete không tính phí (plan §17.5).
    def autocomplete(input, session_token:, lat: DEFAULT_LAT, lng: DEFAULT_LNG, radius: DEFAULT_BIAS_RADIUS_M)
      post("#{BASE}/places:autocomplete", AUTOCOMPLETE_MASK, {
        input: input,
        sessionToken: session_token,
        languageCode: "vi",
        includedRegionCodes: [ "vn" ],
        locationBias: { circle: { center: { latitude: lat, longitude: lng }, radius: radius } }
      })
    end

    def details(place_id, session_token: nil)
      cache_key = "gplace/#{place_id}/v1"

      # Details có session token phải thật sự đi tới Google để kết thúc phiên
      # autocomplete. Trả cache ở đây sẽ biến phiên đó thành abandoned session
      # và từng request autocomplete bị tính phí riêng.
      if session_token.present?
        payload = get(details_url(place_id, session_token: session_token), DETAILS_MASK)
        Rails.cache.write(cache_key, payload, expires_in: CACHE_TTL)
        payload
      else
        Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
          get(details_url(place_id), DETAILS_MASK)
        end
      end
    end

    private

    def details_url(place_id, session_token: nil)
      query = { languageCode: "vi", regionCode: "VN" }
      query[:sessionToken] = session_token if session_token.present?
      "#{BASE}/places/#{CGI.escape(place_id)}?#{URI.encode_www_form(query)}"
    end

    def get(url, mask)
      request = Net::HTTP::Get.new(URI(url))
      perform(request, mask)
    end

    def post(url, mask, body)
      request = Net::HTTP::Post.new(URI(url))
      request.body = body.to_json
      perform(request, mask)
    end

    def perform(request, mask)
      uri = request.uri
      request["Content-Type"]     = "application/json"
      request["X-Goog-Api-Key"]   = @api_key
      request["X-Goog-FieldMask"] = mask

      response = Net::HTTP.start(uri.hostname, uri.port,
                                 use_ssl: true, open_timeout: TIMEOUT_S, read_timeout: TIMEOUT_S) do |http|
        http.request(request)
      end

      request_id = response["x-goog-request-id"]
      unless response.is_a?(Net::HTTPSuccess)
        # Không log body — có thể chứa Maps Content (plan §14.4).
        Rails.logger.warn("[google.places] #{response.code} path=#{uri.path} request_id=#{request_id}")
        raise PlacesError.new("Google Places trả về #{response.code}", status: response.code.to_i, request_id: request_id)
      end

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise PlacesError.new("Google Places timeout sau #{TIMEOUT_S}s: #{e.class}")
    end
  end
end
