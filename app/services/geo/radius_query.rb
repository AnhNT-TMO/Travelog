module Geo
  class RadiusQuery
    MIN_RADIUS_M = 100
    MAX_RADIUS_M = 50_000
    DEFAULT_RADIUS_M = 1_800

    DEFAULT_LAT = 21.0287
    DEFAULT_LNG = 105.8524

    attr_reader :lat, :lng, :radius_m

    def initialize(user:, lat:, lng:, radius_m: DEFAULT_RADIUS_M, state: "all", tag_ids: [])
      @user     = user
      @lat      = lat.presence&.to_f || DEFAULT_LAT
      @lng      = lng.presence&.to_f || DEFAULT_LNG
      @radius_m = radius_m.to_i.clamp(MIN_RADIUS_M, MAX_RADIUS_M)
      @state    = state
      @tag_ids  = tag_ids
    end

    def call
      base.for_state(@state)
          .tagged_with_all(@tag_ids)
          .select(distance_select)
          .with_card_data
          .order(Arel.sql("distance_m ASC"))
    end

    def counts
      scoped = base.tagged_with_all(@tag_ids)
      {
        wishlist: scoped.wishlist.distinct.count,
        visited:  scoped.visited.distinct.count,
        all:      scoped.distinct.count
      }
    end

    def places_without_coords
      @user.user_places.joins(:place).where(places: { lat: nil }).or(
        @user.user_places.joins(:place).where(places: { lng: nil })
      )
    end

    def map_points(user_places)
      user_places.map do |user_place|
        {
          id:     user_place.id,
          lat:    user_place.place.lat,
          lng:    user_place.place.lng,
          name:   user_place.label,
          status: user_place.status
        }
      end
    end

    private

    def base
      @user.user_places.joins(:place).merge(Place.within_radius(@lat, @lng, @radius_m))
    end

    def distance_select
      UserPlace.sanitize_sql_array([
        "user_places.*, earth_distance(ll_to_earth(?, ?), ll_to_earth(places.lat, places.lng)) AS distance_m",
        @lat, @lng
      ])
    end
  end
end
