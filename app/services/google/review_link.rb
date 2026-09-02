module Google
  class ReviewLink
    class << self
      def for(place)
        if place.google_place_id.present?
          "https://search.google.com/local/writereview?placeid=#{place.google_place_id}"
        else
          "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(place.display_name)}"
        end
      end

      def directions_for(place)
        destination = place.coordinates? ? "#{place.lat},#{place.lng}" : place.display_name
        "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(destination)}"
      end

      def fallback_for(place)
        if place.google_place_id.present?
          "https://www.google.com/maps/place/?q=place_id:#{place.google_place_id}"
        else
          "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(place.display_name)}"
        end
      end
    end
  end
end
