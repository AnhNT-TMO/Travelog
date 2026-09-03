require "test_helper"

class CollectionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @tag = create(:tag, user: @user, name: "Coffee")
    @user_place = create(:user_place, user: @user)
    Tagging.create!(tag: @tag, user_place: @user_place)
    @photo = create(:photo, user_place: @user_place)
    sign_in @user
  end

  test "cover bộ sưu tập được chuẩn bị ở controller" do
    get root_path

    assert_response :success
    assert_select "a[href=?]", places_tag_path(@tag), count: 2
    assert_select "img[src=?]", @photo.thumb_url, count: 1
    assert_equal @user_place,
                 @controller.view_assigns["collection_covers_by_tag"][@tag.id]
  end

  test "trang chủ chỉ hiện 6 nhóm nhiều nơi nhất và nút xem tất cả" do
    7.times { |index| create(:tag, user: @user, kind: :vibe, name: "vibe-#{index}") }

    get root_path

    assert_response :success
    assert_equal 6, @controller.view_assigns["vibe_tags"].size
    assert_equal 8, @controller.view_assigns["group_counts"][:vibe]
    assert_select "a[href=?]", tag_collections_path("vibe")
  end

  test "trang nhóm hiện toàn bộ tag của loại đó" do
    7.times { |index| create(:tag, user: @user, kind: :vibe, name: "vibe-#{index}") }

    get tag_collections_path("vibe")

    assert_response :success
    assert_equal 8, @controller.view_assigns["tags"].size
  end

  test "trang chủ hiện các địa điểm chưa đánh tag" do
    untagged = create(:user_place, user: @user)

    get root_path

    assert_response :success
    assert_equal [ untagged ], @controller.view_assigns["untagged_places"]
    assert_equal 1, @controller.view_assigns["group_counts"][:untagged]
  end

  test "danh sách chưa đánh tag sắp theo id tăng dần" do
    first  = create(:user_place, user: @user)
    second = create(:user_place, user: @user)

    get untagged_collections_path

    assert_response :success
    assert_equal [ first, second ], @controller.view_assigns["user_places"]
  end

  test "trang nhóm sắp tag theo số địa điểm giảm dần" do
    busy  = create(:tag, user: @user, kind: :vibe, name: "aaa-busy")
    quiet = create(:tag, user: @user, kind: :vibe, name: "aaa-quiet")
    3.times { Tagging.create!(tag: busy, user_place: create(:user_place, user: @user)) }
    2.times { Tagging.create!(tag: quiet, user_place: create(:user_place, user: @user)) }

    get tag_collections_path("vibe")

    assert_response :success
    assert_equal [ busy, quiet ], @controller.view_assigns["tags"].first(2)
  end

  test "trang chưa đánh tag chỉ lấy địa điểm không có tagging nào" do
    untagged = create(:user_place, user: @user)
    create(:user_place)

    get untagged_collections_path

    assert_response :success
    assert_equal [ untagged ], @controller.view_assigns["user_places"]
  end

  test "địa điểm rời khỏi danh sách chưa đánh tag sau khi được gắn tag" do
    untagged = create(:user_place, user: @user)
    Tagging.create!(tag: @tag, user_place: untagged)

    get untagged_collections_path

    assert_response :success
    assert_empty @controller.view_assigns["user_places"]
  end
end
