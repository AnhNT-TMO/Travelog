require "test_helper"

class PublicCollectionTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @tag  = create(:tag, user: @user, name: "Cafe hồ Tây", kind: :area)

    @user_place = create(:user_place, :visited,
                         user: @user,
                         note: "GHI CHU RIENG TU",
                         my_rating: 5,
                         priority: true,
                         source_url: "https://www.tiktok.com/@hanoifood/video/999",
                         google_review_state: :reviewed,
                         review_body_draft: "BAN NHAP REVIEW",
                         place: create(:place, display_name: "Sen Tây Hồ"))

    Tagging.create!(tag: @tag, user_place: @user_place)
  end

  test "share tắt thì link trả 404" do
    get public_collection_path("khong-ton-tai")

    assert_response :not_found
  end

  test "bật share rồi thì xem được mà không cần đăng nhập" do
    @tag.enable_sharing!
    get public_collection_path(@tag.public_token)

    assert_response :success
    assert_match "Sen Tây Hồ", response.body
    assert_match "Cafe hồ Tây", response.body
  end

  test "tắt share thì link cũ chết" do
    @tag.enable_sharing!
    token = @tag.public_token
    @tag.disable_sharing!

    get public_collection_path(token)

    assert_response :not_found
  end

  test "bật lại share sinh token MỚI, link cũ không sống lại" do
    @tag.enable_sharing!
    old_token = @tag.public_token
    @tag.disable_sharing!
    @tag.enable_sharing!

    assert_not_equal old_token, @tag.public_token
    get public_collection_path(old_token)

    assert_response :not_found
  end

  test "trang public KHÔNG lộ field riêng tư" do
    @tag.enable_sharing!
    get public_collection_path(@tag.public_token)

    assert_response :success
    assert_no_match(/tiktok\.com/, response.body, "source_url bị lộ")
    assert_no_match(/BAN NHAP REVIEW/, response.body, "review_body_draft bị lộ")
    assert_no_match(/GHI CHU RIENG TU/, response.body, "note bị lộ khi chưa bật share_notes")
    assert_no_match(/reviewed/i, response.body, "trạng thái review bị lộ")
    assert_no_match(/★/, response.body, "my_rating bị lộ")
    assert_no_match(/Ưu tiên/, response.body, "priority bị lộ")
  end

  test "note chỉ hiện khi bật share_notes" do
    @tag.enable_sharing!(share_notes: true)
    get public_collection_path(@tag.public_token)

    assert_match "GHI CHU RIENG TU", response.body
  end

  test "gửi header noindex" do
    @tag.enable_sharing!
    get public_collection_path(@tag.public_token)

    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end
end
