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
    assert_select "img[src=?]", @photo.thumb_url, count: 2
    assert_equal @user_place,
                 @controller.view_assigns["collection_covers_by_tag"][@tag.id]
  end
end
