module PhotosHelper
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
