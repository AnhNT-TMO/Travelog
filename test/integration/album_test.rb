require "test_helper"

class AlbumTest < ActionDispatch::IntegrationTest
  setup do
    @user       = create(:user)
    @user_place = create(:user_place, user: @user, status: :visited)
    sign_in @user
  end

  test "ảnh của chính lần đến hiện trong dòng của lần đó" do
    visit = create(:visit, user_place: @user_place, visited_at: 3.days.ago)
    photo = create(:photo, user_place: @user_place, visit: visit)

    get album_path

    assert_response :success
    assert_select "img[src=?]", photo.thumb_url
  end

  test "ảnh thêm ngoài luồng check-in gom vào lần đến gần nhất, chỉ hiện một lần" do
    create(:visit, user_place: @user_place, visited_at: 20.days.ago)
    recent = create(:visit, user_place: @user_place, visited_at: 2.days.ago)
    photo  = create(:photo, user_place: @user_place, visit: nil)

    get album_path

    assert_response :success
    assert_select "img[src=?]", photo.thumb_url, count: 1
    assert_equal [ photo ], @controller.view_assigns["photos_by_visit"][recent]
  end

  test "thumbstrip chỉ tải bản 400, không phát srcset" do
    visit = create(:visit, user_place: @user_place, visited_at: 1.day.ago)
    photo = create(:photo, user_place: @user_place, visit: visit)

    get album_path

    assert_select "img[src=?]", photo.thumb_url do |images|
      assert_nil images.first["srcset"]
      assert_nil images.first["sizes"]
    end
    assert_select "img[src*=?]", "/preview/", count: 0
  end

  test "ảnh rời của người khác không lọt vào album" do
    visit = create(:visit, user_place: @user_place, visited_at: 1.day.ago)
    other = create(:user_place, user: create(:user), place: @user_place.place)
    stray = create(:photo, user_place: other, visit: nil)

    get album_path

    assert_response :success
    assert_select "img[src=?]", stray.thumb_url, count: 0
    assert_empty @controller.view_assigns["photos_by_visit"][visit]
  end

  test "ngoài khoảng ngày thì không hiện" do
    visit = create(:visit, user_place: @user_place, visited_at: 2.years.ago)
    photo = create(:photo, user_place: @user_place, visit: visit)

    get album_path

    assert_response :success
    assert_select "img[src=?]", photo.thumb_url, count: 0
  end
end
