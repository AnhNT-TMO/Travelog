# Thứ tự ưu tiên khi chọn ngôn ngữ:
#   1. ?locale=  — người dùng vừa bấm nút đổi ngôn ngữ (và được ghi nhớ lại)
#   2. users.locale — lựa chọn đã lưu của người đang đăng nhập
#   3. session — dùng cho trang public, nơi không có current_user
#   4. Accept-Language của browser
#   5. I18n.default_locale (:vi)
#
# Locale KHÔNG nằm trong URL: link chia sẻ /s/:token phải giữ nguyên hình dạng,
# và app nội bộ không cần URL riêng cho từng ngôn ngữ.
module Localizable
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
    helper_method :current_locale, :available_locales
  end

  private

  def switch_locale(&)
    I18n.with_locale(resolve_locale, &)
  end

  def current_locale = I18n.locale

  def available_locales = I18n.available_locales

  def resolve_locale
    requested = supported_locale(params[:locale])
    remember_locale(requested) if requested

    requested ||
      supported_locale(current_user&.locale) ||
      supported_locale(session[:locale]) ||
      locale_from_header ||
      I18n.default_locale
  end

  def remember_locale(locale)
    session[:locale] = locale.to_s
    # Ghi vào user để giữ lựa chọn qua nhiều thiết bị; bỏ qua nếu chưa đăng nhập.
    current_user&.update_column(:locale, locale.to_s) if current_user&.locale != locale.to_s
  end

  # Đủ dùng cho 2 ngôn ngữ: lấy tag đầu tiên trong Accept-Language mà app hỗ trợ.
  # Bỏ qua q-value vì browser đã xếp sẵn theo thứ tự ưu tiên.
  def locale_from_header
    header = request.env["HTTP_ACCEPT_LANGUAGE"].presence
    return nil if header.nil?

    header.scan(/[a-zA-Z]{2}(?:-[a-zA-Z]{2})?/)
          .lazy
          .filter_map { |tag| supported_locale(tag.split("-").first) }
          .first
  end

  def supported_locale(value)
    return nil if value.blank?

    locale = value.to_s.downcase.to_sym
    locale if I18n.available_locales.include?(locale)
  end
end
