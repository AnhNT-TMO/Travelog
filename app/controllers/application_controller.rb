class ApplicationController < ActionController::Base
  include Localizable

  NEARBY_CENTER_KEY = "nearby_center".freeze

  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_user
  before_action :load_sidebar_tags
  before_action :set_pending_reviews_count

  stale_when_importmap_changes

  private

  def scoped_places
    current_user.user_places
  end

  def scoped_tags
    current_user.tags
  end

  def nearby_center
    session[NEARBY_CENTER_KEY]
  end

  def remember_nearby_center(lat, lng, name = nil)
    session[NEARBY_CENTER_KEY] = {
      "lat"  => lat.to_f,
      "lng"  => lng.to_f,
      "name" => name.presence,
      "at"   => Time.current.to_i
    }
  end

  def set_current_user
    Current.user = current_user
  end

  def load_sidebar_tags
    return unless user_signed_in?

    @sidebar_tags = scoped_tags.ordered.to_a
  end

  def set_pending_reviews_count
    return unless user_signed_in?

    @pending_reviews_count = scoped_places.needing_google_review.count
  end
end
