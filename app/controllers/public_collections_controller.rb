# Chia sẻ read-only (D18, plan §23).
# CẢNH BÁO: đây là route công khai duy nhất của một app nội bộ. Không render
# shared/_place_card ở đây — partial đó có source_url, trạng thái review,
# my_rating (plan §23.4). Chỉ dùng public_collections/_place_card.
class PublicCollectionsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_user
  skip_before_action :load_sidebar_tags
  skip_forgery_protection   # chỉ GET, không có form

  layout "public"

  rate_limit to: 60, within: 1.minute

  def show
    @tag = Tag.share_unlisted.find_by!(public_token: params[:public_token])

    @user_places = @tag.user_places
                       .with_card_data
                       .order(status: :desc, created_at: :desc)

    @counts = {
      visited:  @user_places.count(&:visited?),
      wishlist: @user_places.count(&:wishlist?)
    }

    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    expires_in 5.minutes, public: false
  end
end
