module Google
  # KHÔNG có API nào đăng review lên Google Maps, và automation vi phạm ToS
  # (plan D12, §12.1). App chỉ mở deep link + copy nội dung + tải ảnh.
  class ReviewLink
    class << self
      def for(place)
        if place.google_place_id.present?
          "https://search.google.com/local/writereview?placeid=#{place.google_place_id}"
        else
          "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(place.display_name)}"
        end
      end

      # Chỉ đường: ưu tiên toạ độ vì tên tiếng Việt hay khớp nhầm quán khác.
      def directions_for(place)
        destination = place.coordinates? ? "#{place.lat},#{place.lng}" : place.display_name
        "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(destination)}"
      end

      # Deep link writereview hoạt động không nhất quán theo vùng — luôn hiện
      # link này bên dưới với chữ "Không mở được? Thử link này".
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
