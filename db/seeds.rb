email    = ENV["SEED_EMAIL"].presence
password = ENV["SEED_PASSWORD"].presence

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
  puts "Bỏ qua seed user (#{Rails.env}): cần cả SEED_EMAIL và SEED_PASSWORD."
end

unless Rails.env.development?
  puts "Môi trường #{Rails.env}: không seed dữ liệu mẫu."
  return
end

AREA_TAGS = [
  [ "Hồ Tây",    "#0E6E63" ],
  [ "Phố cổ",    "#A06E10" ],
  [ "Hồ Gươm",   "#7E9BB8" ],
  [ "Ecopark",   "#A85F52" ],
  [ "Long Biên", "#6E8452" ],
  [ "Cầu Giấy",  "#8A5F3C" ],
  [ "Đống Đa",   "#5F7E8A" ],
  [ "Hai Bà Trưng", "#8A527E" ],
  [ "Mỹ Đình",   "#A0873C" ]
].freeze

VIBE_TAGS = [ "chill", "rooftop", "làm việc", "view hồ", "tiktok", "hẹn hò", "ăn khuya", "brunch" ].freeze

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
  [ "Bánh mì Trần Thái Tông",   :food,  21.0325, 105.7900, "Cầu Giấy",   "Cầu Giấy",  [], false ],
  [ "Tiệm Bánh Sáng Trung Hoà", :cafe,  21.0180, 105.7955, "Cầu Giấy",   "Cầu Giấy",  %w[brunch], false ],
  [ "Cộng Cà Phê Láng Hạ",      :cafe,  21.0155, 105.8130, "Đống Đa",    "Đống Đa",   [ "làm việc" ], false ],
  [ "Nướng Ngói Hoàng Cầu",     :food,  21.0225, 105.8175, "Đống Đa",    "Đống Đa",   [ "ăn khuya" ], true ],
  [ "Bún đậu Ngõ Thịnh Quang",  :food,  21.0075, 105.8215, "Đống Đa",    "Đống Đa",   [ "ăn khuya" ], false ],
  [ "Cà phê Vườn Trần Khát Chân", :cafe, 21.0105, 105.8570, "Hai Bà Trưng", "Hai Bà Trưng", [ "hẹn hò", "chill" ], true ],
  [ "Lẩu Nấm Bạch Mai",         :food,  21.0020, 105.8510, "Hai Bà Trưng", "Hai Bà Trưng", [ "hẹn hò" ], false ],
  [ "Brunch House Mỹ Đình",     :cafe,  21.0290, 105.7640, "Nam Từ Liêm", "Mỹ Đình",   [ "brunch", "làm việc" ], false ]
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
  user_place.priority = [ true, false, false ].sample if user_place.new_record?
  user_place.source_url = "https://www.tiktok.com/@hanoifood/video/#{rand(10**18)}" if vibes.include?("tiktok")
  user_place.save!

  ([ area_by_name[area] ] + vibes.map { |vibe| vibe_by_name[vibe] }).compact.each do |tag|
    Tagging.find_or_create_by!(tag: tag, user_place: user_place)
  end

  [ user_place, been ]
end

user_places.select { |_, been| been }.each_with_index do |(user_place, _), index|
  visited_at = (index * 22).days.ago.change(hour: 10 + (index % 8))
  next if user_place.visits.where(visited_at: visited_at).exists?

  user_place.visits.create!(
    visited_at: visited_at,
    note: [ "Bánh sen ngon", "Đi buổi chiều muộn", nil, "Đông quá, lần sau đi sớm" ].sample,
    source: :manual
  )
end

UNTAGGED_PLACES = [
  { name: "Bánh Cuốn Bà Hoành",             type: :food,  lat: 21.0340, lng: 105.8455, district: "Hoàn Kiếm",
    source: "https://www.tiktok.com/@hanoifood/video/7412903845100000011" },
  { name: "Cà phê Muối 3 Anh Em",           type: :cafe,  lat: 21.0165, lng: 105.8225, district: "Đống Đa",
    source: "https://www.tiktok.com/@hanoicafe/video/7412903845100000012" },
  { name: "Quán Ốc Cô Oanh Nghĩa Tân",      type: :food,  lat: 21.0405, lng: 105.7925, district: "Cầu Giấy",
    source: "https://www.facebook.com/reel/1122334455667788" },
  { name: "Chè Bốn Mùa Hàng Cân",           type: :food,  lat: 21.0350, lng: 105.8500, district: "Hoàn Kiếm",
    source: "https://www.tiktok.com/@hanoifood/video/7412903845100000013", note: "Linh rec, đi buổi tối" },
  { name: "Ramen Ryukishin Trần Duy Hưng",  type: :food,  lat: 21.0080, lng: 105.7990, district: "Cầu Giấy" },
  { name: "Bún ngan Nhàn",                  type: :food,  lat: 21.0320, lng: 105.8480, district: "Hoàn Kiếm" },
  { name: "Tiệm cà phê view cầu Nhật Tân",  type: :cafe,
    source: "https://www.tiktok.com/@hanoicafe/video/7412903845100000014" },
  { name: "Nhà hàng Nhật ngõ 21 Kim Mã",    type: :food,
    source: "https://www.tiktok.com/@hanoifood/video/7412903845100000015" },
  { name: "Rooftop Hàng Buồm",              type: :other, nickname: "quán rooftop trong video",
    source: "https://www.tiktok.com/@hanoicafe/video/7412903845100000016" }
].freeze

UNTAGGED_PLACES.each do |attrs|
  place = Place.find_or_initialize_by(display_name: attrs[:name])
  place.update!(
    place_type:     attrs[:type],
    lat:            attrs[:lat],
    lng:            attrs[:lng],
    coords_source:  :manual,
    city:           attrs[:district] ? "Hà Nội" : nil,
    district:       attrs[:district],
    cached_address: attrs[:district] ? "#{attrs[:district]}, Hà Nội" : nil
  )

  user_place = user.user_places.find_or_initialize_by(place: place)

  if user_place.new_record?
    user_place.nickname   = attrs[:nickname]
    user_place.note       = attrs[:note]
    user_place.source_url = attrs[:source]
  end

  user_place.save!
end

puts "Seed xong: #{User.count} user · #{Place.count} place · #{UserPlace.count} user_place · " \
     "#{Tag.count} tag · #{Visit.count} visit · #{UserPlace.where.missing(:taggings).count} chưa đánh tag"
puts "Đăng nhập: #{user.email} / #{password}"
