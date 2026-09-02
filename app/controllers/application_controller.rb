class ApplicationController < ActionController::Base
  include Localizable

  NEARBY_CENTER_KEY = "nearby_center".freeze

  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_user
  before_action :load_sidebar_tags

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

  def remember_nearby_center(lat, lng)
    session[NEARBY_CENTER_KEY] = { "lat" => lat.to_f, "lng" => lng.to_f }
  end

  def set_current_user
    Current.user = current_user
  end

  def load_sidebar_tags
    return unless user_signed_in?

    @sidebar_tags = scoped_tags.ordered.to_a
  end
end
