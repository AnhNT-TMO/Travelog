module ApplicationHelper
  # Ảnh của Google Place Photos thuộc SKU đắt nên nơi CHƯA ĐẾN không có ảnh
  # thật. Thay vì để ô xám, sinh gradient tất định theo tag.
  PLACEHOLDER_GRADIENTS = [
    [ "#C9A882", "#8A5F3C", "#4A3020" ],
    [ "#8FB8A8", "#3E7565", "#1E3C34" ],
    [ "#F0C97A", "#C98B3B", "#7A4E18" ],
    [ "#7E9BB8", "#3D5B78", "#1B2C3C" ],
    [ "#D9A9A0", "#A85F52", "#5C2E26" ],
    [ "#B6C4A0", "#6E8452", "#33401F" ],
    [ "#CFCAC0", "#8B857A", "#454039" ],
    [ "#A9A6C8", "#5C5880", "#2A2740" ]
  ].freeze

  def placeholder_gradient_style(seed)
    from, via, to = PLACEHOLDER_GRADIENTS[seed.to_s.sum % PLACEHOLDER_GRADIENTS.size]
    "background-image: linear-gradient(155deg, #{from} 0%, #{via} 55%, #{to} 100%)"
  end

  # Khoảng cách luôn hiển thị bằng km một chữ số thập phân, font mono.
  def distance_label(meters)
    return nil if meters.blank?

    t("common.distance_km", value: number_with_precision(meters.to_f / 1000, precision: 1))
  end

  # Nhãn trạng thái là chuỗi cho NGƯỜI ĐỌC nên nằm ở view layer, không nằm ở
  # model — model chỉ giữ enum wishlist/visited.
  def status_label(user_place) = t("status.#{user_place.status}")

  def status_pill_class(user_place)
    user_place.visited? ? "pill pill--visited" : "pill pill--wish"
  end

  def review_label(user_place)
    user_place.review_reviewed? ? t("review.reviewed") : t("review.not_reviewed")
  end

  def review_pill_class(user_place)
    user_place.review_reviewed? ? "pill pill--reviewed" : "pill pill--noreview"
  end

  # "Tháng 8 · 2026" / "August · 2026" — tên tháng do rails-i18n cung cấp.
  def month_label(date)
    "#{I18n.t('date.month_names')[date.month]} · #{date.year}"
  end

  # Link đổi ngôn ngữ: giữ nguyên URL hiện tại, chỉ thêm ?locale=
  def locale_switch_path(locale)
    url_for(request.query_parameters.merge(locale: locale))
  end
end
