require "test_helper"

class TagPlacesFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @area = create(:tag, user: @user, name: "Hồ Tây", kind: :area)
    @chill = create(:tag, user: @user, name: "chill", kind: :vibe)

    @wishlist = create(:user_place, user: @user, status: :wishlist)
    @visited = create(:user_place, :visited, user: @user)
    @without_vibe = create(:user_place, user: @user, status: :wishlist)

    [ @wishlist, @visited, @without_vibe ].each do |user_place|
      Tagging.create!(tag: @area, user_place: user_place)
    end
    Tagging.create!(tag: @chill, user_place: @wishlist)
    Tagging.create!(tag: @chill, user_place: @visited)

    sign_in @user
  end

  test "vibe filter composes with the area tag and marks the chip selected" do
    get places_tag_path(@area), params: { state: "wishlist", vibe: [ @chill.id ] }

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(@wishlist)}"
    assert_select "##{ActionView::RecordIdentifier.dom_id(@without_vibe)}", count: 0
    assert_select ".chip[aria-pressed='true']", text: /chill/
  end

  test "state navigation renders the selected tab from the URL" do
    get places_tag_path(@area), params: { state: "visited" }

    assert_response :success
    assert_select ".seg[data-controller='segmented']"
    assert_select "a[role='tab'][aria-selected='true']", text: /Đã đến/
    assert_select "a[role='tab'][data-turbo-frame]", count: 0
  end

  test "place cards escape the list frame when opening details" do
    get places_tag_path(@area), params: { state: "wishlist" }

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(@wishlist)}[data-turbo-frame='_top']"
  end

  test "sort=distance without a centre says so instead of silently reordering" do
    get places_tag_path(@area), params: { state: "wishlist", sort: "distance" }

    assert_response :success
    assert_select ".hint", text: /Chưa có điểm trung tâm/
    assert_select ".hint", text: /Sắp theo khoảng cách/, count: 0
  end

  test "sort=distance orders by the centre remembered from the nearby screen" do
    near = create(:user_place, user: @user, place: create(:place, lat: 21.0287, lng: 105.8524))
    far  = create(:user_place, user: @user, place: create(:place, lat: 21.0680, lng: 105.8180))
    [ near, far ].each { |user_place| Tagging.create!(tag: @area, user_place: user_place) }

    get nearby_path, params: { lat: 21.0287, lng: 105.8524 }
    assert_response :success

    get places_tag_path(@area), params: { state: "wishlist", sort: "distance" }

    assert_response :success
    assert_select ".hint", text: /Sắp theo khoảng cách/
    body = response.body
    assert_operator body.index(ActionView::RecordIdentifier.dom_id(near)),
                    :<,
                    body.index(ActionView::RecordIdentifier.dom_id(far)),
                    "địa điểm gần tâm phải đứng trước địa điểm xa hơn"
  end

  test "sort=distance nói ra số nơi bị loại vì thiếu toạ độ" do
    no_coords = create(:user_place, user: @user, place: create(:place, lat: nil, lng: nil))
    Tagging.create!(tag: @area, user_place: no_coords)

    get nearby_path, params: { lat: 21.0287, lng: 105.8524 }
    get places_tag_path(@area), params: { state: "wishlist", sort: "distance" }

    assert_response :success
    assert_select "##{ActionView::RecordIdentifier.dom_id(no_coords)}", count: 0
    assert_select ".text-ochre", text: /không có toạ độ/
  end
end
