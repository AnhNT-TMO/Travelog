# Tab "Tôi" trên mobile — mockup M1..M6 có ô này ở bottom nav. Trên desktop
# cùng nội dung đã nằm ở chân sidebar, nên trang này chủ yếu phục vụ mobile.
class AccountController < ApplicationController
  def show
    @tags_count   = scoped_tags.count
    @places_count = scoped_places.count
    @visits_count = Visit.where(user_place: scoped_places).count
  end
end
