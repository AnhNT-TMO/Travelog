class ApplicationController < ActionController::Base
  include Localizable

  # Only allow modern browsers supporting webp images, web push, badges, import
  # maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_user
  before_action :load_sidebar_tags

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # MỌI truy cập dữ liệu người dùng đi qua đây. Không bao giờ UserPlace.find(...)
  # hay Tag.find(...) — sẽ cho người khác đọc dữ liệu của bạn (plan §14.3).
  def scoped_places
    current_user.user_places
  end

  def scoped_tags
    current_user.tags
  end

  def set_current_user
    Current.user = current_user
  end

  # Sidebar (desktop) hiện cây tag ở mọi trang → load một lần ở đây.
  def load_sidebar_tags
    return unless user_signed_in?

    @sidebar_tags = scoped_tags.ordered.to_a
  end
end
