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
