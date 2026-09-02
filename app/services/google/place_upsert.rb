module Google
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
