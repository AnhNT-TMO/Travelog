module PhotosHelper
  # App nội bộ cố ý KHÔNG fallback về original: derivative hỏng phải lộ ra ngay
  # thay vì âm thầm tải file gốc nặng hơn. onerror đổi ảnh thành biểu tượng lỗi.
  # srcset: false cho ô nhỏ (thumbstrip album) — với srcset, màn hình DPR 2x/3x
  # chọn bản 1200 cho một ô 76px, tải thừa băng thông mà mắt không thấy khác.
  def photo_image_tag(photo, sizes:, derivative_size: Photos::ThumbnailUrl::THUMB, css_class: "", srcset: true)
    return nil if photo.blank?

    image = image_tag(
      photo.thumb_url(derivative_size),
      srcset: (photo.srcset if srcset),
      sizes: (sizes if srcset),
      loading: "lazy",
      decoding: "async",
      alt: "",
      class: "h-full w-full object-cover #{css_class}",
      onerror: "this.hidden=true;this.nextElementSibling.hidden=false"
    )

    error_icon = content_tag(
      :span,
      "▧",
      hidden: true,
      role: "img",
      aria: { label: t("common.image_unavailable") },
      class: "grid h-full w-full place-items-center bg-surface-2 text-lg text-muted"
    )

    content_tag(:span, safe_join([ image, error_icon ]), class: "relative block h-full w-full")
  end
end
