require "test_helper"

class VisitTest < ActiveSupport::TestCase
  setup do
    @user_place = create(:user_place, status: :wishlist)
  end

  test "tạo visit chuyển user_place sang visited và cập nhật mốc thời gian" do
    visited_at = 3.days.ago.change(usec: 0)
    create(:visit, user_place: @user_place, visited_at: visited_at)
    @user_place.reload

    assert @user_place.visited?
    assert_equal 1, @user_place.visits_count
    assert_equal visited_at.to_i, @user_place.first_visited_at.to_i
    assert_equal visited_at.to_i, @user_place.last_visited_at.to_i
  end

  test "nhiều lần đến giữ đúng first và last visited_at" do
    older = 40.days.ago.change(usec: 0)
    newer = 2.days.ago.change(usec: 0)

    create(:visit, user_place: @user_place, visited_at: newer)
    create(:visit, user_place: @user_place, visited_at: older)
    @user_place.reload

    assert_equal 2, @user_place.visits_count
    assert_equal older.to_i, @user_place.first_visited_at.to_i
    assert_equal newer.to_i, @user_place.last_visited_at.to_i
  end

  test "hai visit trùng thời điểm vẫn có thứ tự timeline ổn định" do
    visited_at = 1.day.ago.change(usec: 0)
    first = create(:visit, user_place: @user_place, visited_at: visited_at)
    second = create(:visit, user_place: @user_place, visited_at: visited_at)

    assert_equal [ second.id, first.id ], @user_place.visits.chronological.ids
  end

  test "destroy visit cuối cùng đưa counters về 0" do
    visit = create(:visit, user_place: @user_place)
    visit.destroy!
    @user_place.reload

    assert_equal 0, @user_place.visits_count
    assert @user_place.wishlist?
    assert_nil @user_place.first_visited_at
    assert_nil @user_place.last_visited_at
  end

  test "destroy user_place kéo theo visit mà không nổ FrozenError" do
    create(:visit, user_place: @user_place)

    assert_nothing_raised { @user_place.destroy! }
    assert_equal 0, Visit.count
  end

  test "destroy_all trên user_place xoá sạch cả visits" do
    create(:visit, user_place: @user_place)
    create(:visit, user_place: create(:user_place))

    assert_nothing_raised { UserPlace.destroy_all }
    assert_equal 0, UserPlace.count
    assert_equal 0, Visit.count
  end
end
