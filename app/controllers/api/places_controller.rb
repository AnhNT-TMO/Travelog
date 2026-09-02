module Api
  class PlacesController < ApplicationController
    SESSION_TOKEN_PATTERN = /\A[A-Za-z0-9_-]{1,36}\z/
    MAX_INPUT_LENGTH = 200

    def autocomplete
      input = params[:q].to_s.strip.first(MAX_INPUT_LENGTH)
      return render json: { suggestions: [] } if input.length < 3

      payload = places_client.autocomplete(
        input,
        session_token: session_token,
        lat: coordinate(:lat, Google::PlacesClient::DEFAULT_LAT, -90..90),
        lng: coordinate(:lng, Google::PlacesClient::DEFAULT_LNG, -180..180)
      )

      render json: { suggestions: predictions(payload) }
    rescue Google::PlacesError
      render_unavailable
    end

    def details
      payload = places_client.details(place_id, session_token: session_token)
      render json: Google::PlaceSnapshot.new(payload).response_attributes
    rescue KeyError, Google::PlacesError
      render_unavailable
    end

    private

    def places_client
      @places_client ||= Google::PlacesClient.new
    end

    def session_token
      token = params[:session_token].to_s
      return token if SESSION_TOKEN_PATTERN.match?(token)

      raise ActionController::BadRequest, "invalid autocomplete session token"
    end

    def place_id
      id = params[:place_id].to_s
      return id if id.present? && id.length <= 255

      raise ActionController::BadRequest, "invalid Google place id"
    end

    def coordinate(name, default, range)
      value = Float(params[name], exception: false)
      range.cover?(value) ? value : default
    end

    def predictions(payload)
      Array(payload["suggestions"]).filter_map do |suggestion|
        prediction = suggestion["placePrediction"]
        next if prediction.blank?

        {
          place_id: prediction["placeId"],
          text: prediction.dig("text", "text"),
          main_text: prediction.dig("structuredFormat", "mainText", "text"),
          secondary_text: prediction.dig("structuredFormat", "secondaryText", "text")
        }
      end
    end

    def render_unavailable
      render json: { error: t("api.places.unavailable") }, status: :bad_gateway
    end
  end
end
