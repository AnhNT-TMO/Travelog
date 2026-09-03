require "test_helper"

class PhotoDownloadsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user_place = create(:user_place, user: @user)
    @first_photo = attached_photo("first-original.jpg", "first original")
    @second_photo = attached_photo("second-original.jpg", "second original")
    sign_in @user
  end

  test "gallery renders a swipeable carousel, thumbnail controls, and original downloads" do
    get place_path(@user_place)

    assert_response :success
    assert_select "[data-controller~='carousel'][data-controller~='lightbox']", count: 1
    assert_select "[data-carousel-target='viewport'].snap-x", count: 2
    assert_select "[data-carousel-target='slide'].media-skeleton", count: 2
    assert_select "button[data-carousel-target='thumbnail']", count: 2
    assert_select "[data-carousel-target='thumbnailViewport']", count: 1 do
      assert_select "[data-controller='bulk-download']", count: 0
      assert_select "form", count: 0
    end
    assert_select "a[href='#{download_place_photo_path(@user_place, @first_photo)}']", count: 1
    assert_select "[data-controller='bulk-download']" \
                  "[data-bulk-download-url-value='#{download_all_place_photos_path(@user_place, format: :json)}']",
                  count: 1
    assert_select "button[data-bulk-download-target='button']", count: 1
  end

  test "deleting a photo selects the following photo" do
    third_photo = attached_photo("third-original.jpg", "third original")

    delete place_photo_path(@user_place, @second_photo)

    assert_redirected_to place_path(@user_place, photo: third_photo)
    follow_redirect!
    assert_select "[data-carousel-initial-index-value='1']"
    assert_select "button[data-carousel-index='1'][aria-pressed='true']"
  end

  test "gallery opens every photo full size in a lightbox" do
    get place_path(@user_place)

    assert_response :success
    assert_select "[data-controller~='lightbox']", count: 1
    assert_select "button[data-action='lightbox#open'][data-lightbox-index='0']", count: 1
    assert_select "button[data-action='lightbox#open'][data-lightbox-index='1']", count: 1
    assert_select "[data-lightbox-target='panel'][hidden]", count: 1 do
      assert_select "[data-controller~='carousel']", count: 1
      assert_select "[data-lightbox-target='viewport'].snap-x", count: 1
      assert_select "[data-lightbox-target='slide']", count: 2
      assert_select "[data-lightbox-target='slide'] img.object-contain\\!", count: 2
    end
  end

  test "review photo selection updates inside its own Turbo Frame" do
    create(:visit, user_place: @user_place)

    get place_path(@user_place)

    assert_response :success
    assert_select "turbo-frame#review_attachments_user_place_#{@user_place.id}" do
      assert_select "form[action='#{toggle_google_selection_place_photo_path(@user_place, @first_photo)}']", count: 1
      assert_select "form[action='#{mark_reviewed_place_review_kit_path(@user_place)}']", count: 0
    end
    assert_select "form[action='#{mark_reviewed_place_review_kit_path(@user_place)}']", count: 1
  end

  test "individual download redirects to the original attachment" do
    get download_place_photo_path(@user_place, @first_photo)

    assert_response :redirect
    2.times { follow_redirect! }
    assert_response :success
    assert_equal "first original", response.body
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "download all lists every original as its own download link" do
    get download_all_place_photos_path(@user_place, format: :json)

    assert_response :success
    assert_equal "application/json", response.media_type

    files = response.parsed_body["files"]
    assert_equal [ "first-original.jpg", "second-original.jpg" ], files.map { |file| file["name"] }
    assert_equal rails_blob_path(@first_photo.file, disposition: "attachment"), files.first["url"]

    get files.first["url"]
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "first original", response.body
  end

  test "download all skips photos whose original never landed in storage" do
    create(:photo, user_place: @user_place, s3_key: "#{@user_place.id}/missing.jpg")

    get download_all_place_photos_path(@user_place, format: :json)

    assert_response :success
    assert_equal [ "first-original.jpg", "second-original.jpg" ],
                 response.parsed_body["files"].map { |file| file["name"] }
  end

  test "downloads cannot access another user's photos" do
    other_place = create(:user_place)
    other_photo = create(:photo, user_place: other_place)

    get download_place_photo_path(other_place, other_photo)
    assert_response :not_found

    sign_in @user
    get download_all_place_photos_path(other_place, format: :json)
    assert_response :not_found
  end

  private

  def attached_photo(filename, contents)
    photo = create(:photo, user_place: @user_place, s3_key: "#{@user_place.id}/#{filename}")
    photo.file.attach(io: StringIO.new(contents), filename: filename, content_type: "image/jpeg")
    photo
  end
end
