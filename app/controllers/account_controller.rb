class AccountController < ApplicationController
  def show
    @tags_count   = scoped_tags.count
    @places_count = scoped_places.count
    @visits_count = Visit.where(user_place: scoped_places).count
  end
end
