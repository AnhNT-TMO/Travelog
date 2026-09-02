require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @alice = create(:user)
    @bob   = create(:user)

    @bob_place = create(:user_place, user: @bob)
    @bob_tag   = create(:tag, user: @bob, name: "riêng của bob")
    Tagging.create!(tag: @bob_tag, user_place: @bob_place)
  end

  test "user A không xem được địa điểm của user B" do
    sign_in @alice

    get place_path(@bob_place)

    assert_response :not_found
  end

  test "user A không xem được tag của user B" do
    sign_in @alice

    get places_tag_path(@bob_tag)

    assert_response :not_found
  end

  test "chưa đăng nhập thì bị đẩy về trang login" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "đăng nhập rồi thì vào được trang chủ" do
    sign_in @alice
    get root_path

    assert_response :success
  end
end
