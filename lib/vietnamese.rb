module Vietnamese
  module_function

  def slugify(text)
    strip_accents(text).parameterize
  end

  def strip_accents(text)
    text.to_s
        .unicode_normalize(:nfd)
        .gsub(/\p{Mn}/, "")
        .tr("đĐ", "dD")
        .unicode_normalize(:nfc)
  end
end
