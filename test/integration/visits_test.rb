require "test_helper"

class VisitsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user_place = create(:user_place, user: @user)
    sign_in @user
  end

  test "check-in rollback cả visit lẫn ảnh nếu một ảnh không lưu được" do
    blob = direct_upload_blob(key: "#{@user_place.id}/duplicate-a1b2c3.jpg")

    assert_no_difference([ "Visit.count", "Photo.count" ]) do
      post place_visits_path(@user_place), params: {
        visit: { visited_at: Time.current },
        photos: [ blob.signed_id, blob.signed_id ]
      }
      assert_response :unprocessable_content
    end

    assert @user_place.reload.wishlist?
  end

  test "lần đến hiển thị thao tác sửa và xoá" do
    visit = create(:visit, user_place: @user_place)
    photo = create(:photo, user_place: @user_place, user: @user, visit: visit)

    get place_path(@user_place)

    assert_response :success
    assert_select "#visit_#{visit.id}[data-controller='sheet']" do
      assert_select "button[data-action='sheet#open']", text: "Sửa"
      assert_select "form[action='#{place_visit_path(@user_place, visit)}'][method='post']", count: 2
      assert_select "input[name='remove_photo_ids[]'][value='#{photo.id}']", count: 1
    end
  end

  test "cập nhật nội dung của lần đến" do
    visit = create(:visit, user_place: @user_place, note: "Cũ")
    visited_at = Time.zone.local(2026, 9, 1, 18, 30)

    patch place_visit_path(@user_place, visit), params: {
      visit: { visited_at: visited_at, note: "Nội dung mới" }
    }

    assert_redirected_to place_path(@user_place, anchor: "visit_#{visit.id}")
    visit.reload
    assert_equal visited_at, visit.visited_at
    assert_equal "Nội dung mới", visit.note
  end

  test "cập nhật lần đến có thể thêm và xoá ảnh nhưng không đụng ảnh của lần khác" do
    visit = create(:visit, user_place: @user_place)
    other_visit = create(:visit, user_place: @user_place)
    removed_photo = create(:photo, user_place: @user_place, user: @user, visit: visit)
    kept_photo = create(:photo, user_place: @user_place, user: @user, visit: other_visit)
    blob = direct_upload_blob(key: "#{@user_place.id}/new-visit-photo.jpg")

    assert_no_difference("Photo.count") do
      patch place_visit_path(@user_place, visit), params: {
        visit: { visited_at: visit.visited_at, note: visit.note },
        remove_photo_ids: [ removed_photo.id, kept_photo.id ],
        photos: [ blob.signed_id ]
      }
    end

    assert_redirected_to place_path(@user_place, anchor: "visit_#{visit.id}")
    assert_not Photo.exists?(removed_photo.id)
    assert Photo.exists?(kept_photo.id)
    assert_equal visit, Photo.find_by!(s3_key: blob.key).visit
  end

  test "không thể sửa lần đến của người khác" do
    other_visit = create(:visit)

    patch place_visit_path(other_visit.user_place, other_visit), params: {
      visit: { visited_at: Time.current, note: "Không được phép" }
    }

    assert_response :not_found
    assert_not_equal "Không được phép", other_visit.reload.note
  end

  test "xoá lần đến vẫn giữ ảnh trong kho" do
    visit = create(:visit, user_place: @user_place)
    photo = create(:photo, user_place: @user_place, user: @user, visit: visit)

    assert_difference("Visit.count", -1) do
      assert_no_difference("Photo.count") do
        delete place_visit_path(@user_place, visit)
      end
    end

    assert_redirected_to place_path(@user_place, anchor: "visits")
    assert_nil photo.reload.visit_id
  end

  private

  def direct_upload_blob(key:)
    content = "test"
    checksum = Base64.strict_encode64(Digest::MD5.digest(content))
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      key: key,
      filename: File.basename(key),
      byte_size: content.bytesize,
      checksum: checksum,
      content_type: "image/jpeg"
    )
    blob.service.upload(blob.key, StringIO.new(content), checksum: checksum)
    blob
  end
end
