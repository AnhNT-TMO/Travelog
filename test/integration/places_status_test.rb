require "test_helper"

class PlacesStatusTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user
  end

  test "form địa điểm không cho nhập trạng thái thủ công" do
    get new_place_path

    assert_response :success
    assert_select "input[name='user_place[status]']", count: 0
  end

  test "bỏ qua status giả mạo và giữ wishlist khi chưa có visit" do
    assert_difference("@user.user_places.count", 1) do
      post places_path, params: {
        user_place: {
          status: "visited",
          place_attributes: { display_name: "Manual place", place_type: "cafe" }
        }
      }
    end

    assert_redirected_to place_path(@user.user_places.order(:id).last)
    assert @user.user_places.order(:id).last.wishlist?
  end
end
