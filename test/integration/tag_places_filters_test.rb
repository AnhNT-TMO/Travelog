require "test_helper"

class TagPlacesFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @area = create(:tag, user: @user, name: "Hồ Tây", kind: :area)
    @chill = create(:tag, user: @user, name: "chill", kind: :vibe)

    @wishlist = create(:user_place, user: @user, status: :wishlist)
    @visited = create(:user_place, user: @user, status: :visited)
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
end
