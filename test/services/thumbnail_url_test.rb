require "test_helper"

class ThumbnailUrlTest < ActiveSupport::TestCase
  PLACE_ID = 7
  KEY = "7/abc123def456.jpg".freeze

  test "sinh URL tất định theo cdn_host và size" do
    assert_equal "https://cdn.test.local/7/thumb/abc123def456.webp",
                 Photos::ThumbnailUrl.call(KEY, 400, place_id: PLACE_ID)
    assert_equal "https://cdn.test.local/7/preview/abc123def456.webp",
                 Photos::ThumbnailUrl.call(KEY, 1200, place_id: PLACE_ID)
  end

  test "hai size, thumb 400 và preview 1200" do
    assert_equal [ 400, 1200 ], Photos::ThumbnailUrl::SIZES
    assert_equal 400,  Photos::ThumbnailUrl::THUMB
    assert_equal 1200, Photos::ThumbnailUrl::PREVIEW
  end

  test "mặc định là thumb" do
    assert_equal Photos::ThumbnailUrl.call(KEY, 400, place_id: PLACE_ID),
                 Photos::ThumbnailUrl.call(KEY, place_id: PLACE_ID)
  end

  test "size không hỗ trợ thì raise" do
    assert_raises(ArgumentError) { Photos::ThumbnailUrl.call(KEY, 1600, place_id: PLACE_ID) }
  end

  test "srcset liệt kê đúng mọi size trong SIZES" do
    assert_equal "https://cdn.test.local/7/thumb/abc123def456.webp 400w, " \
                 "https://cdn.test.local/7/preview/abc123def456.webp 1200w",
                 Photos::ThumbnailUrl.srcset(KEY, place_id: PLACE_ID)
  end

  test "key rỗng trả nil thay vì URL hỏng" do
    assert_nil Photos::ThumbnailUrl.call("", place_id: PLACE_ID)
    assert_nil Photos::ThumbnailUrl.srcset(nil, place_id: PLACE_ID)
  end
end
