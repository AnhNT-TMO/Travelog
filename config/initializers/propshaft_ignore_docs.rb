require "propshaft/load_path"

module IgnoreNonAssetDocs
  NON_ASSET_EXTENSIONS = %w[.md].freeze

  private

  def without_dotfiles(files)
    super.reject { |file| NON_ASSET_EXTENSIONS.include?(file.extname) }
  end
end

Propshaft::LoadPath.prepend(IgnoreNonAssetDocs)
