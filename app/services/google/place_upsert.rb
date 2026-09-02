module Google
  # Gộp Place dùng chung theo google_place_id và làm mới snapshot khách quan.
  # display_name là dữ liệu của app nên chỉ khởi tạo từ Google cho Place mới;
  # refresh không ghi đè tên đã được người dùng chỉnh trước đó.
  class PlaceUpsert
    def initialize(details:)
      @snapshot = PlaceSnapshot.new(details)
    end

    def call
      place = Place.find_or_initialize_by(google_place_id: @snapshot.google_place_id)
      assign_snapshot(place)
      place.save!
      place
    rescue ActiveRecord::RecordNotUnique
      place = Place.find_by!(google_place_id: @snapshot.google_place_id)
      assign_snapshot(place)
      place.save!
      place
    end

    private

    def assign_snapshot(place)
      place.display_name = @snapshot.display_name if place.new_record?
      place.assign_attributes(@snapshot.place_attributes)
    end
  end
end
