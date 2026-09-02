require "test_helper"

class PhotoTest < ActiveSupport::TestCase
  setup do
    @user_place = create(:user_place)
  end

  # Cùng lỗi production như VisitTest: touch_counters chạy sau commit, lúc đó
  # user_place đã frozen nên update_columns nổ FrozenError. Ảnh không gắn visit
  # để chỉ còn callback của Photo trong đường chạy — có visit thì Visit
  # #sync_parent nổ trước và test không nói được gì về Photo.
  test "destroy user_place kéo theo ảnh rời mà không nổ FrozenError" do
    create(:photo, user_place: @user_place)

    assert_nothing_raised { @user_place.destroy! }
    assert_equal 0, Photo.count
  end

  test "destroy user_place kéo theo cả visit lẫn ảnh của visit đó" do
    visit = create(:visit, user_place: @user_place)
    create(:photo, user_place: @user_place, visit: visit)

    assert_nothing_raised { @user_place.destroy! }
    assert_equal 0, Photo.count
    assert_equal 0, Visit.count
  end

  test "destroy một ảnh vẫn cập nhật counters của user_place và visit" do
    visit = create(:visit, user_place: @user_place)
    photo = create(:photo, user_place: @user_place, visit: visit)
    create(:photo, user_place: @user_place, visit: visit)

    photo.destroy!

    assert_equal 1, @user_place.reload.photos_count
    assert_equal 1, visit.reload.photos_count
  end
end
