require "test_helper"

class UserPlaceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @chill   = create(:tag, user: @user, name: "chill")
    @rooftop = create(:tag, user: @user, name: "rooftop")

    @both   = create(:user_place, user: @user)
    @only_chill = create(:user_place, user: @user)

    Tagging.create!(tag: @chill,   user_place: @both)
    Tagging.create!(tag: @rooftop, user_place: @both)
    Tagging.create!(tag: @chill,   user_place: @only_chill)
  end

  test "tagged_with_all là AND chứ không phải OR" do
    found = @user.user_places.tagged_with_all([ @chill.id, @rooftop.id ])

    assert_equal [ @both.id ], found.map(&:id)
  end

  test "tagged_with_all với một tag trả về mọi nơi có tag đó" do
    found = @user.user_places.tagged_with_all([ @chill.id ])

    assert_equal [ @both.id, @only_chill.id ].sort, found.map(&:id).sort
  end

  test "tagged_with_all rỗng không lọc gì" do
    assert_equal 2, @user.user_places.tagged_with_all([]).count
  end

  test "tagged_with_all kết hợp được với join tag có sẵn" do
    area = create(:tag, user: @user, name: "Hồ Tây", kind: :area)
    Tagging.create!(tag: area, user_place: @both)
    Tagging.create!(tag: area, user_place: @only_chill)

    in_area = @user.user_places.joins(:taggings).where(taggings: { tag_id: area.id })

    assert_equal [ @both.id, @only_chill.id ].sort,
                 in_area.tagged_with_all([ @chill.id ]).map(&:id).sort
    assert_equal [ @both.id ], in_area.tagged_with_all([ @chill.id, @rooftop.id ]).map(&:id)
  end

  test "label ưu tiên nickname rồi mới tới display_name" do
    place = create(:place, display_name: "Sen Tây Hồ")
    user_place = create(:user_place, user: @user, place: place)

    assert_equal "Sen Tây Hồ", user_place.label

    user_place.update!(nickname: "Quán sen")
    assert_equal "Quán sen", user_place.label
  end

  test "for_state lọc đúng theo trạng thái" do
    create(:visit, user_place: @both)

    assert_equal [ @both.id ], @user.user_places.for_state("visited").map(&:id)
    assert_equal [ @only_chill.id ], @user.user_places.for_state("wishlist").map(&:id)
    assert_equal 2, @user.user_places.for_state("all").count
  end

  test "attach_photos chỉ nhận blob được mint cho đúng place" do
    blob = direct_upload_blob(key: "#{@both.id}/photo-a1b2c3.jpg")

    assert_difference("@both.photos.count", 1) do
      @both.attach_photos!([ blob.signed_id ], user: @user)
    end
  end

  test "attach_photos từ chối blob của place khác" do
    blob = direct_upload_blob(key: "#{@only_chill.id}/private-a1b2c3.jpg")

    assert_no_difference("@both.photos.count") do
      assert_raises(ActiveRecord::RecordNotFound) do
        @both.attach_photos!([ blob.signed_id ], user: @user)
      end
    end
  end

  test "attach_photos rollback toàn bộ khi một ảnh trong nhóm không lưu được" do
    blob = direct_upload_blob(key: "#{@both.id}/duplicate-a1b2c3.jpg")

    assert_no_difference("@both.photos.count") do
      assert_raises(ActiveRecord::RecordInvalid) do
        @both.attach_photos!([ blob.signed_id, blob.signed_id ], user: @user)
      end
    end
  end

  test "không cho đặt trạng thái visited nếu chưa có visit" do
    @both.status = :visited

    assert_not @both.valid?
    assert @both.errors.of_kind?(:status, :invalid)
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

  test "matching khớp tên quán không dấu" do
    target = create(:user_place, user: @user, place: create(:place, display_name: "Sen Tây Hồ Deli"))

    assert_equal [ target.id ], @user.user_places.matching("sen tay ho").map(&:id)
  end

  test "matching khớp nickname không dấu" do
    target = create(:user_place, user: @user, nickname: "quán rooftop trong video")

    assert_equal [ target.id ], @user.user_places.matching("ROOFTOP TRONG VIDEO").map(&:id)
  end

  test "matching khớp link đã lưu dù dán kèm tham số theo dõi" do
    target = create(:user_place, user: @user,
                    source_url: "https://www.tiktok.com/@hanoifood/video/7412903845100000011")

    found = @user.user_places.matching(
      "https://www.tiktok.com/@hanoifood/video/7412903845100000011?is_from_webapp=1&sender_device=pc"
    )

    assert_equal [ target.id ], found.map(&:id)
  end

  test "matching khớp link dán thiếu www hoặc thiếu scheme" do
    target = create(:user_place, user: @user,
                    source_url: "https://www.tiktok.com/@hanoifood/video/7412903845100000012")

    assert_equal [ target.id ], @user.user_places.matching("tiktok.com/@hanoifood/video/7412903845100000012").map(&:id)
  end

  test "matching không lấy link khi từ khoá không phải link" do
    create(:user_place, user: @user, source_url: "https://www.tiktok.com/@hanoicafe/video/7412903845100000013")

    assert_empty @user.user_places.matching("hanoicafe")
  end

  test "matching rỗng không lọc gì" do
    assert_equal @user.user_places.count, @user.user_places.matching("  ").count
  end
end
