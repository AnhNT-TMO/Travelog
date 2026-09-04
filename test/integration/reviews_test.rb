require "test_helper"

class ReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user
  end

  test "hàng đợi chỉ gồm chỗ đã đến mà chưa review, xếp theo thứ tự lưu vào" do
    first  = create(:user_place, :visited, user: @user, place: create(:place, display_name: "Chỗ cũ nhất"))
    second = create(:user_place, :visited, user: @user, place: create(:place, display_name: "Chỗ mới hơn"))
    create(:user_place, user: @user, place: create(:place, display_name: "Chỗ chưa đến"))
    create(:user_place, :visited, user: @user, place: create(:place, display_name: "Chỗ đã review"))
      .update!(google_review_state: :reviewed)

    get reviews_path

    assert_response :success
    assert_select "a[href=?]", reviews_path(place: first.id)
    assert_select "a[href=?]", reviews_path(place: second.id)
    assert_select "body", text: /Chỗ chưa đến/, count: 0
    assert_select "body", text: /Chỗ đã review/, count: 0
    assert_equal [ first.id, second.id ], @controller.view_assigns["user_places"].map(&:id)
    assert_equal first.id, @controller.view_assigns["user_place"].id
  end

  test "chọn một chỗ trong hàng đợi thì mở bộ kit của chỗ đó" do
    create(:user_place, :visited, user: @user)
    target = create(:user_place, :visited, user: @user, place: create(:place, display_name: "Cà phê Giảng"))

    get reviews_path(place: target.id)

    assert_response :success
    assert_equal target.id, @controller.view_assigns["user_place"].id
    assert_equal 2, @controller.view_assigns["position"]
    assert_select "a[href=?]", Google::ReviewLink.maps_for(target.place)
    assert_select "a[href=?]", place_path(target)
  end

  test "chỗ của user khác không lọt vào hàng đợi" do
    other = create(:user_place, :visited, user: create(:user), place: create(:place, display_name: "Chỗ của người khác"))
    other.update!(google_review_state: :not_reviewed)

    get reviews_path

    assert_response :success
    assert_empty @controller.view_assigns["user_places"]
    assert_select "body", text: /Chỗ của người khác/, count: 0
  end

  test "chọn place id không thuộc hàng đợi thì rơi về chỗ đầu tiên" do
    first = create(:user_place, :visited, user: @user)
    reviewed = create(:user_place, :visited, user: @user)
    reviewed.update!(google_review_state: :reviewed)

    get reviews_path(place: reviewed.id)

    assert_response :success
    assert_equal first.id, @controller.view_assigns["user_place"].id
  end

  test "đánh dấu đã review từ trang quản lý thì quay lại trang quản lý" do
    user_place = create(:user_place, :visited, user: @user)

    patch mark_reviewed_place_review_kit_path(user_place),
          headers: { "Referer" => reviews_url(place: user_place.id) }

    assert_redirected_to reviews_url(place: user_place.id)
    assert user_place.reload.review_reviewed?
  end

  test "hàng đợi rỗng thì hiện trạng thái trống" do
    get reviews_path

    assert_response :success
    assert_select "body", text: /Không còn chỗ nào chờ review/
  end

  test "bước soạn nội dung chỉ có một ô nhập, kèm nút copy và nút AI viết lại" do
    user_place = create(:user_place, :visited, user: @user)

    get reviews_path

    assert_response :success
    assert_select "textarea", count: 1
    assert_select "textarea##{ActionView::RecordIdentifier.dom_id(user_place, :review_body_draft)}", count: 1
    assert_select "button[formaction=?]", rewrite_place_review_kit_path(user_place), text: /AI viết lại/, count: 1
    assert_select "button:not([disabled])", text: /Copy nội dung/, count: 1
  end
end
