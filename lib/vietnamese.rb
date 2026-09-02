# ActiveSupport#parameterize đi qua I18n.transliterate, mà bảng mặc định chỉ
# phủ Latin-1: "Hồ Tây" ra "h-tay", "Phố cổ" ra "ph-c". Slug là khoá unique và
# nằm trong URL nên phải bỏ dấu cho đúng.
module Vietnamese
  module_function

  # "Hồ Tây" -> "ho-tay" · "Phố cổ" -> "pho-co" · "Đền Ngọc Sơn" -> "den-ngoc-son"
  def slugify(text)
    strip_accents(text).parameterize
  end

  # Dùng cho so khớp tên không dấu ở phía Ruby. Phía Postgres là
  # lower(immutable_unaccent(...)) — hai bên phải cho cùng kết quả.
  def strip_accents(text)
    text.to_s
        .unicode_normalize(:nfd)
        .gsub(/\p{Mn}/, "")       # bỏ dấu thanh và dấu mũ
        .tr("đĐ", "dD")
        .unicode_normalize(:nfc)
  end
end
