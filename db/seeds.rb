# Seed. Idempotent — chạy lại nhiều lần không nhân đôi.
#
# FILE NÀY CHẠY TỰ ĐỘNG TRÊN PRODUCTION. bin/docker-entrypoint gọi db:prepare,
# và db:prepare nạp seed khi database vừa được tạo — xem
# ActiveRecord::Tasks::DatabaseTasks#prepare_all: `seed = true if
# database_initialized && db_config.seeds?`. Nên mọi thứ ở đây phải an toàn với
# một môi trường thật, và không được raise (raise = container không boot nổi).
#
# Phân chia:
#   - User: mọi môi trường. Nhưng ngoài development thì phải khai SEED_EMAIL +
#     SEED_PASSWORD rõ ràng — không có mật khẩu mặc định trên máy thật.
#   - Dữ liệu mẫu (tag, place, visit): CHỈ development. Trên production người
#     dùng tự thêm từng cái.
#
# Muốn chặn hẳn mọi seed ở production thì thêm `seeds: false` vào khối
# production của config/database.yml — Rails sẽ không gọi file này nữa.
#
#   docker compose exec web bin/rails db:seed

email    = ENV["SEED_EMAIL"].presence
password = ENV["SEED_PASSWORD"].presence

# Mặc định chỉ tồn tại ở development. Đây là lý do: một mật khẩu mặc định nằm
# trong git mà lại tạo được account trên production là lỗ hổng, không phải tiện.
if Rails.env.development?
  email    ||= "anh.nguyentien@pixta.co.jp"
  password ||= "travelog123"
end

if email && password
  user = User.find_or_initialize_by(email: email)
  user.display_name = ENV.fetch("SEED_DISPLAY_NAME") { email.split("@").first }
  user.password = password
  user.save!
  puts "User: #{user.email}"
else
  # Không raise: db:prepare chạy lúc container boot, raise ở đây là app không
  # lên được. Thiếu biến thì bỏ qua, tạo user bằng `bin/kamal console`.
  puts "Bỏ qua seed user (#{Rails.env}): cần cả SEED_EMAIL và SEED_PASSWORD."
end

unless Rails.env.development?
  puts "Môi trường #{Rails.env}: không seed dữ liệu mẫu."
  return
end

# ---------------------------------------------------------------------------
# Từ đây trở xuống CHỈ chạy ở development.
#
# Toạ độ là toạ độ THẬT của Hà Nội: test radius filter chỉ có nghĩa khi khoảng
# cách giữa các điểm là khoảng cách thật (plan §18).
# ---------------------------------------------------------------------------

AREA_TAGS = [
  [ "Hồ Tây",    "#0E6E63" ],
  [ "Phố cổ",    "#A06E10" ],
  [ "Hồ Gươm",   "#7E9BB8" ],
  [ "Ecopark",   "#A85F52" ],
  [ "Long Biên", "#6E8452" ],
  [ "Cầu Giấy",  "#8A5F3C" ]
].freeze

VIBE_TAGS = [ "chill", "rooftop", "làm việc", "view hồ", "tiktok" ].freeze

area_tags = AREA_TAGS.each_with_index.map do |(name, color), index|
  tag = user.tags.find_or_initialize_by(slug: Vietnamese.slugify(name))
  tag.update!(name: name, kind: :area, color: color, position: index)
  tag
end

vibe_tags = VIBE_TAGS.each_with_index.map do |name, index|
  tag = user.tags.find_or_initialize_by(slug: Vietnamese.slugify(name))
  tag.update!(name: name, kind: :vibe, position: index)
  tag
end

area_by_name = area_tags.index_by(&:name)
vibe_by_name = vibe_tags.index_by(&:name)

# [tên, type, lat, lng, district, area tag, [vibe tags], đã đến?]
PLACES = [
  [ "Sen Tây Hồ Deli",          :cafe,  21.0680, 105.8180, "Tây Hồ",     "Hồ Tây",    %w[chill], false ],
  [ "Ban Công Cafe",            :cafe,  21.0450, 105.8390, "Ba Đình",    "Hồ Tây",    [ "chill", "view hồ" ], true ],
  [ "Chiều Hồ Coffee & Books",  :cafe,  21.0790, 105.8210, "Tây Hồ",     "Hồ Tây",    [ "chill", "làm việc" ], false ],
  [ "Nhà Sàn Cafe",             :cafe,  21.0730, 105.8250, "Tây Hồ",     "Hồ Tây",    [ "view hồ" ], false ],
  [ "Góc Nhỏ 46 Từ Hoa",        :cafe,  21.0665, 105.8225, "Tây Hồ",     "Hồ Tây",    %w[chill], true ],
  [ "Rooftop 88 Xuân Diệu",     :cafe,  21.0640, 105.8290, "Tây Hồ",     "Hồ Tây",    [ "rooftop", "tiktok" ], false ],
  [ "Bờ Kè Coffee",             :cafe,  21.0820, 105.8160, "Tây Hồ",     "Hồ Tây",    [ "view hồ" ], false ],
  [ "Tiệm cà phê Trứng Ngõ 27", :cafe,  21.0310, 105.8520, "Hoàn Kiếm",  "Phố cổ",    %w[tiktok], false ],
  [ "Bún chả Hàng Quạt",        :food,  21.0335, 105.8495, "Hoàn Kiếm",  "Phố cổ",    [], true ],
  [ "Phở Bát Đàn",              :food,  21.0345, 105.8470, "Hoàn Kiếm",  "Phố cổ",    [], true ],
  [ "Cafe Giảng",               :cafe,  21.0330, 105.8540, "Hoàn Kiếm",  "Phố cổ",    %w[chill], true ],
  [ "Đền Ngọc Sơn",             :sight, 21.0300, 105.8525, "Hoàn Kiếm",  "Hồ Gươm",   [], true ],
  [ "Cafe Đinh",                :cafe,  21.0295, 105.8515, "Hoàn Kiếm",  "Hồ Gươm",   [ "view hồ" ], true ],
  [ "Highlands Nhà Hát Lớn",    :cafe,  21.0245, 105.8575, "Hoàn Kiếm",  "Hồ Gươm",   [ "làm việc" ], false ],
  [ "Ecopark Sky Oasis",        :sight, 20.9660, 105.9350, "Văn Giang",  "Ecopark",   %w[chill], false ],
  [ "Cỏ Cafe Ecopark",          :cafe,  20.9700, 105.9310, "Văn Giang",  "Ecopark",   [ "chill", "làm việc" ], true ],
  [ "Xưởng Gạch Coffee",        :cafe,  21.0470, 105.8760, "Long Biên",  "Long Biên", [ "làm việc" ], false ],
  [ "Cầu Long Biên",            :sight, 21.0435, 105.8620, "Long Biên",  "Long Biên", [], true ],
  [ "The Coffee House Duy Tân", :cafe,  21.0300, 105.7860, "Cầu Giấy",   "Cầu Giấy",  [ "làm việc" ], false ],
  [ "Bánh mì Trần Thái Tông",   :food,  21.0325, 105.7900, "Cầu Giấy",   "Cầu Giấy",  [], false ]
].freeze

user_places = PLACES.map do |name, type, lat, lng, district, area, vibes, been|
  place = Place.find_or_initialize_by(display_name: name)
  place.update!(
    place_type: type,
    lat: lat,
    lng: lng,
    coords_source: :manual,
    city: "Hà Nội",
    district: district,
    cached_address: "#{district}, Hà Nội"
  )

  user_place = user.user_places.find_or_initialize_by(place: place)
  user_place.status ||= been ? :visited : :wishlist
  user_place.priority = [ true, false, false ].sample if user_place.new_record?
  user_place.source_url = "https://www.tiktok.com/@hanoifood/video/#{rand(10**18)}" if vibes.include?("tiktok")
  user_place.save!

  ([ area_by_name[area] ] + vibes.map { |vibe| vibe_by_name[vibe] }).compact.each do |tag|
    Tagging.find_or_create_by!(tag: tag, user_place: user_place)
  end

  [ user_place, been ]
end

# ~8 lần đến rải trong 6 tháng để album có ít nhất 4 tháng khác nhau.
user_places.select { |_, been| been }.first(8).each_with_index do |(user_place, _), index|
  visited_at = (index * 22).days.ago.change(hour: 10 + (index % 8))
  next if user_place.visits.where(visited_at: visited_at).exists?

  user_place.visits.create!(
    visited_at: visited_at,
    note: [ "Bánh sen ngon", "Đi buổi chiều muộn", nil, "Đông quá, lần sau đi sớm" ].sample,
    companions: [ "một mình", "cùng Linh", nil ].sample,
    source: :manual
  )
end

puts "Seed xong: #{User.count} user · #{Place.count} place · #{UserPlace.count} user_place · " \
     "#{Tag.count} tag · #{Visit.count} visit"
puts "Đăng nhập: #{user.email} / #{password}"
