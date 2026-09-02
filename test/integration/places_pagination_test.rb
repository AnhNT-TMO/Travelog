require "test_helper"

class PlacesPaginationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user_places = create_list(:user_place, 25, user: @user)
    sign_in @user
  end

  test "mỗi trang chỉ hiển thị tối đa 20 địa điểm" do
    get places_path

    assert_response :success
    assert_select "a[id^='user_place_']", count: 20
    assert_select "nav[aria-label='Phân trang địa điểm']", count: 1
    assert_select "a[data-turbo-action='advance']", text: "Trang sau"
  end

  test "trang thứ hai hiển thị phần còn lại" do
    get places_path, params: { page: 2 }

    assert_response :success
    assert_select "a[id^='user_place_']", count: 5
    assert_select ".num", text: "Trang 2 / 2"
    assert_select "a", text: "Trang trước"
  end

  test "link phân trang giữ lại từ khoá tìm kiếm" do
    get places_path, params: { q: "Quán" }

    assert_response :success
    assert_select "a[id^='user_place_']", count: 20
    assert_select "a[href=?]", places_path(q: "Quán", page: 2), count: 1
  end
end
