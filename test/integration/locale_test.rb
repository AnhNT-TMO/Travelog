require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "mặc định là tiếng Việt" do
    sign_in @user
    get root_path

    assert_response :success
    assert_select "html[lang=?]", "vi"
    assert_match "Bộ sưu tập", response.body
  end

  test "?locale=en đổi sang tiếng Anh" do
    sign_in @user
    get root_path, params: { locale: "en" }

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_match "Collections", response.body
  end

  test "lựa chọn ngôn ngữ được ghi nhớ ở request sau" do
    sign_in @user
    get root_path, params: { locale: "en" }
    get root_path

    assert_select "html[lang=?]", "en"
    assert_equal "en", @user.reload.locale
  end

  test "locale không hỗ trợ thì rơi về mặc định" do
    sign_in @user
    get root_path, params: { locale: "fr" }

    assert_select "html[lang=?]", "vi"
  end

  test "Accept-Language được dùng khi người dùng chưa chọn gì" do
    sign_in @user
    get root_path, headers: { "Accept-Language" => "en-GB,en;q=0.9" }

    assert_select "html[lang=?]", "en"
  end

  test "trang public cũng đổi ngôn ngữ được và không cần đăng nhập" do
    tag = create(:tag, user: @user, name: "Cafe hồ Tây")
    tag.enable_sharing!

    get public_collection_path(tag.public_token), params: { locale: "en" }

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_match "Shared collection", response.body
  end
end
