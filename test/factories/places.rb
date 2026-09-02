FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@travelog.test" }
    password { "travelog123" }
  end

  factory :place do
    sequence(:display_name) { |n| "Quán số #{n}" }
    place_type { :cafe }
    # Hồ Gươm
    lat { 21.0287 }
    lng { 105.8524 }
    coords_source { :manual }
    city { "Hà Nội" }
    district { "Hoàn Kiếm" }
  end

  factory :user_place do
    user
    place
    status { :wishlist }
  end

  factory :tag do
    user
    sequence(:name) { |n| "tag-#{n}" }
    kind { :vibe }
  end

  factory :visit do
    user_place
    visited_at { 2.days.ago }
    source { :manual }
  end

  # Không attach file thật: s3_key là thứ duy nhất pipeline ảnh quan tâm, và
  # Photo#copy_key_from_blob chỉ điền khi s3_key còn trống.
  factory :photo do
    user_place
    user { user_place.user }
    sequence(:s3_key) { |n| "seedkey#{n}" }
  end
end
