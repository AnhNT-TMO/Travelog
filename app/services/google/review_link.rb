module Google
  class ReviewLink
    class << self
      def maps_for(place)
        query = [ place.display_name, place.cached_address ].compact_blank.join(", ")
        parameters = [ "api=1", "query=#{CGI.escape(query)}" ]
        parameters << "query_place_id=#{CGI.escape(place.google_place_id)}" if place.google_place_id.present?

        "https://www.google.com/maps/search/?#{parameters.join("&")}"
      end

      def directions_for(place)
        if place.google_place_id.present?
          destination = CGI.escape(place.display_name)
          place_id = CGI.escape(place.google_place_id)
          "https://www.google.com/maps/dir/?api=1&destination=#{destination}&destination_place_id=#{place_id}"
        else
          destination = place.coordinates? ? "#{place.lat},#{place.lng}" : place.display_name
          "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(destination)}"
        end
      end
    end
  end
end
