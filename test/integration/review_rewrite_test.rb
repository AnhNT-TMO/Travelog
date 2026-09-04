require "test_helper"

class ReviewRewriteEndpointTest < ActionDispatch::IntegrationTest
  class StubRewrite
    def initialize(review: nil, error: nil)
      @review = review
      @error = error
      @calls = []
    end

    attr_reader :calls

    def call(notes:, place_type:, **)
      @calls << { notes: notes, place_type: place_type }
      raise Ai::GeminiError, @error if @error

      @review
    end
  end

  setup do
    @user = create(:user)
    sign_in @user
  end

  test "AI đề xuất một bản trong hộp thoại và chưa đụng vào nháp" do
    user_place = create(:user_place, :visited, user: @user, place: create(:place, place_type: :food))
    stub = StubRewrite.new(review: "Đồ ăn vừa miệng, quán rộng rãi.")

    with_stubbed_method(Ai::ReviewRewrite, :new, -> { stub }) do
      patch rewrite_place_review_kit_path(user_place),
            params: { user_place: { review_body_draft: "đồ ăn ổn, quán rộng" } }
    end

    assert_response :success
    assert_equal [ { notes: "đồ ăn ổn, quán rộng", place_type: "Ăn uống" } ], stub.calls
    assert_equal "đồ ăn ổn, quán rộng", user_place.reload.review_body_draft
    assert_select "dialog", text: /Đồ ăn vừa miệng, quán rộng rãi./
    assert_select "form[action=?] input[value=?]",
                  apply_rewrite_place_review_kit_path(user_place), "Đồ ăn vừa miệng, quán rộng rãi."
  end

  test "chọn dùng bản AI thì nháp mới được lưu và hộp thoại biến mất" do
    user_place = create(:user_place, :visited, user: @user)
    user_place.update!(review_body_draft: "đồ ăn ổn, quán rộng")

    patch apply_rewrite_place_review_kit_path(user_place),
          params: { user_place: { review_body_draft: "Đồ ăn vừa miệng, quán rộng rãi." } }

    assert_response :success
    assert_equal "Đồ ăn vừa miệng, quán rộng rãi.", user_place.reload.review_body_draft
    assert_select "dialog", count: 0
    assert_select "textarea", text: /Đồ ăn vừa miệng/
  end

  test "Gemini lỗi thì giữ nguyên ý đã nhập và báo lại cho người dùng" do
    user_place = create(:user_place, :visited, user: @user)
    stub = StubRewrite.new(error: "Gemini trả về 503")

    with_stubbed_method(Ai::ReviewRewrite, :new, -> { stub }) do
      patch rewrite_place_review_kit_path(user_place),
            params: { user_place: { review_body_draft: "cà phê ngon" } }
    end

    assert_response :unprocessable_entity
    assert_equal "cà phê ngon", user_place.reload.review_body_draft
    assert_select "dialog", count: 0
    assert_select "body", text: /AI chưa viết lại được lúc này/
  end

  test "chưa nhập ý nào thì không gọi Gemini" do
    user_place = create(:user_place, :visited, user: @user)
    stub = StubRewrite.new(review: "không nên được gọi")

    with_stubbed_method(Ai::ReviewRewrite, :new, -> { stub }) do
      patch rewrite_place_review_kit_path(user_place), params: { user_place: { review_body_draft: "  " } }
    end

    assert_response :unprocessable_entity
    assert_empty stub.calls
    assert_select "body", text: /AI mới có gì để viết lại/
  end

  test "chỗ của user khác không viết lại được" do
    other = create(:user_place, :visited, user: create(:user))

    patch rewrite_place_review_kit_path(other), params: { user_place: { review_body_draft: "thử xem" } }

    assert_response :not_found
  end

  test "chỗ của user khác không nhận được bản AI" do
    other = create(:user_place, :visited, user: create(:user))

    patch apply_rewrite_place_review_kit_path(other), params: { user_place: { review_body_draft: "thử xem" } }

    assert_response :not_found
    assert_nil other.reload.review_body_draft
  end

  test "chọn tiếng Anh thì AI trả lời theo locale đang dùng" do
    user_place = create(:user_place, :visited, user: @user)
    seen = []
    stub = Object.new
    stub.define_singleton_method(:call) { |notes:, place_type:, **| seen << I18n.locale; "Good coffee." }

    with_stubbed_method(Ai::ReviewRewrite, :new, -> { stub }) do
      patch rewrite_place_review_kit_path(user_place, locale: "en"),
            params: { user_place: { review_body_draft: "good coffee" } }
    end

    assert_response :success
    assert_equal [ :en ], seen
  end
end
