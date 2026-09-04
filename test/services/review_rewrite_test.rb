require "test_helper"

class ReviewRewriteTest < ActiveSupport::TestCase
  setup do
    @service = Ai::ReviewRewrite.new(api_key: "test-key", model: "gemini-test")
  end

  test "prompt tiếng Việt mang theo ý đã nhập và loại quán" do
    sent = nil
    payload = text_payload("Quán chill, cà phê ngon.")

    review = with_stubbed_method(@service, :perform, ->(body) { sent = body; payload }) do
      @service.call(notes: "chill, cà phê ngon", place_type: "Cafe", locale: :vi)
    end

    prompt = sent[:contents].first[:parts].first[:text]
    assert_includes prompt, "chill, cà phê ngon"
    assert_includes prompt, "Cafe"
    assert_includes prompt, "bằng tiếng Việt"
    assert_equal "Quán chill, cà phê ngon.", review
  end

  test "locale en dùng prompt tiếng Anh" do
    sent = nil
    payload = text_payload("Nice and quiet.")

    with_stubbed_method(@service, :perform, ->(body) { sent = body; payload }) do
      @service.call(notes: "chill, good coffee", place_type: "Cafe", locale: :en)
    end

    prompt = sent[:contents].first[:parts].first[:text]
    assert_includes prompt, "written in English"
    assert_includes prompt, "chill, good coffee"
  end

  test "locale lạ rơi về prompt mặc định thay vì đọc file ngoài thư mục prompts" do
    sent = nil
    payload = text_payload("Ổn.")

    with_stubbed_method(@service, :perform, ->(body) { sent = body; payload }) do
      @service.call(notes: "ổn", place_type: "Cafe", locale: "../../../etc/passwd")
    end

    assert_includes sent[:contents].first[:parts].first[:text], "bằng tiếng Việt"
  end

  test "bỏ qua phần thought và ghép các part văn bản" do
    payload = {
      "candidates" => [ { "content" => { "parts" => [
        { "text" => "đang nghĩ", "thought" => true },
        { "text" => "Cà phê ngon, " },
        { "text" => "chỗ ngồi thoải mái." }
      ] } } ]
    }

    review = with_stubbed_method(@service, :perform, ->(_body) { payload }) do
      @service.call(notes: "cà phê ngon", place_type: "Cafe", locale: :vi)
    end

    assert_equal "Cà phê ngon, chỗ ngồi thoải mái.", review
  end

  test "Gemini chặn prompt thì báo lỗi thay vì trả chuỗi rỗng" do
    payload = { "promptFeedback" => { "blockReason" => "SAFETY" } }

    error = assert_raises(Ai::GeminiError) do
      with_stubbed_method(@service, :perform, ->(_body) { payload }) do
        @service.call(notes: "cà phê ngon", place_type: "Cafe", locale: :vi)
      end
    end

    assert_includes error.message, "SAFETY"
  end

  test "không có part văn bản nào thì báo lỗi" do
    payload = { "candidates" => [ { "content" => { "parts" => [ { "text" => "  ", "thought" => true } ] } } ] }

    assert_raises(Ai::GeminiError) do
      with_stubbed_method(@service, :perform, ->(_body) { payload }) do
        @service.call(notes: "cà phê ngon", place_type: "Cafe", locale: :vi)
      end
    end
  end

  test "ý nhập quá dài bị cắt trước khi gửi đi" do
    sent = nil
    notes = "a" * (Ai::ReviewRewrite::MAX_NOTES_CHARS + 500)
    payload = text_payload("Ổn.")

    with_stubbed_method(@service, :perform, ->(body) { sent = body; payload }) do
      @service.call(notes: notes, place_type: "Cafe", locale: :vi)
    end

    prompt = sent[:contents].first[:parts].first[:text]
    assert_includes prompt, "a" * Ai::ReviewRewrite::MAX_NOTES_CHARS
    assert_not_includes prompt, "a" * (Ai::ReviewRewrite::MAX_NOTES_CHARS + 1)
  end

  private

  def text_payload(text)
    { "candidates" => [ { "content" => { "parts" => [ { "text" => text } ] } } ] }
  end
end
