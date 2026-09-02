require "test_helper"

class AssetsTest < ActiveSupport::TestCase
  def load_path = Rails.application.assets.load_path

  test "CLAUDE.md không được đăng ký thành asset" do
    assert_nil load_path.find("CLAUDE.md"),
               "app/javascript/CLAUDE.md đang bị phục vụ ở /assets — bộ lọc trong " \
               "config/initializers/propshaft_ignore_docs.rb không còn tác dụng."
  end

  test "không có file .md nào trong asset load path" do
    markdown = load_path.assets.select { |asset| asset.path.extname == ".md" }

    assert_empty markdown.map { |asset| asset.logical_path.to_s },
                 "Có file markdown lọt vào asset pipeline."
  end

  test "asset JavaScript thật vẫn phục vụ bình thường" do
    assert_not_nil load_path.find("application.js")
    assert_not_nil load_path.find("controllers/nearby_map_controller.js")
    assert_not_nil load_path.find("controllers/index.js")
  end
end
