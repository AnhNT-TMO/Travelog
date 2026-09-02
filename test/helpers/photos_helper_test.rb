require "test_helper"

class PhotosHelperTest < ActionView::TestCase
  test "thumbnail uses the 400 derivative as its primary source" do
    photo = build_stubbed(:photo)

    image = Nokogiri::HTML.fragment(photo_image_tag(photo, sizes: "52px")).at_css("img")

    assert_equal photo.thumb_url(Photos::ThumbnailUrl::THUMB), image["src"]
    assert_equal photo.srcset, image["srcset"]
  end

  test "preview can use the 1200 derivative as its primary source" do
    photo = build_stubbed(:photo)

    image = Nokogiri::HTML.fragment(
      photo_image_tag(photo, sizes: "760px", derivative_size: Photos::ThumbnailUrl::PREVIEW)
    ).at_css("img")

    assert_equal photo.thumb_url(Photos::ThumbnailUrl::PREVIEW), image["src"]
    assert_equal photo.srcset, image["srcset"]
  end

  test "broken derivative shows an error icon without an original fallback" do
    photo = build_stubbed(:photo)
    fragment = Nokogiri::HTML.fragment(photo_image_tag(photo, sizes: "52px"))

    assert_not_includes fragment.to_html, "originals"
    assert_nil fragment.at_css("img")["data-fallback"]
    assert_equal I18n.t("common.image_unavailable"), fragment.at_css("[role='img']")["aria-label"]
  end
end
