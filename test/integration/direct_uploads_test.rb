require "test_helper"

class DirectUploadsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user_place = create(:user_place, user: @user)
    sign_in @user
  end

  test "creates an original blob key grouped by place id" do
    post place_direct_uploads_path(@user_place), params: upload_params("Cà phê Hồ Tây.JPEG"), as: :json

    assert_response :success
    blob = ActiveStorage::Blob.order(:id).last
    assert_match %r{\A#{@user_place.id}/ca-phe-ho-tay-[0-9a-f]{12}\.jpg\z}, blob.key
  end

  test "does not create a key inside another user's place" do
    other_place = create(:user_place)

    assert_no_difference("ActiveStorage::Blob.count") do
      post place_direct_uploads_path(other_place), params: upload_params("private.jpg"), as: :json
    end

    assert_response :not_found
  end

  test "place forms use the scoped direct upload endpoint" do
    get place_path(@user_place)

    assert_response :success
    assert_select "input[type='file'][data-direct-upload-url='#{place_direct_uploads_url(@user_place)}']", count: 2
  end

  private

  def upload_params(filename)
    {
      blob: {
        filename: filename,
        byte_size: 4,
        checksum: Base64.strict_encode64(Digest::MD5.digest("test")),
        content_type: "image/jpeg",
        metadata: {}
      }
    }
  end
end
