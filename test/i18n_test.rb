require "test_helper"
require "i18n/tasks"

class I18nTest < ActiveSupport::TestCase
  def setup
    @i18n = I18n::Tasks::BaseTask.new
    @missing = @i18n.missing_keys
    @unused = @i18n.unused_keys
  end

  test "không có key nào bị thiếu" do
    assert_empty @missing, "Thiếu key (thêm vào cả vi.yml lẫn en.yml):\n#{@missing}"
  end

  test "không có key nào thừa" do
    assert_empty @unused, "Key không còn ai dùng (xoá đi hoặc thêm vào ignore_unused):\n#{@unused}"
  end

  test "file locale đã được normalize" do
    assert_empty @i18n.non_normalized_paths,
                 "Chạy `bundle exec i18n-tasks normalize` để sắp lại file locale."
  end
end
