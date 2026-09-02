require "propshaft/load_path"

# Propshaft coi MỌI file nằm dưới một asset path là asset. app/javascript là
# asset path (do importmap-rails thêm vào), nên app/javascript/CLAUDE.md bị đăng
# ký thành asset: phục vụ ở /assets/CLAUDE-<digest>.md và bị assets:precompile
# copy vào public/assets. Tài liệu hướng dẫn nội bộ không được nằm trên URL công khai.
#
# Propshaft chỉ bỏ qua dotfile, không có ignore list theo file hay theo đuôi,
# và excluded_paths chỉ loại được cả thư mục. Nên thêm bộ lọc ở đây.
#
# test/assets_test.rb chốt lại hành vi này — nếu bản Propshaft mới đổi tên
# internal thì test đỏ, thay vì âm thầm publish lại tài liệu.
module IgnoreNonAssetDocs
  NON_ASSET_EXTENSIONS = %w[.md].freeze

  private

  def without_dotfiles(files)
    super.reject { |file| NON_ASSET_EXTENSIONS.include?(file.extname) }
  end
end

Propshaft::LoadPath.prepend(IgnoreNonAssetDocs)
