FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@travelog.test" }
    password { "travelog123" }
  end

  factory :place do
    sequence(:display_name) { |n| "Quán số #{n}" }
    place_type { :cafe }
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

    trait :visited do
      after(:create) { |user_place| create(:visit, user_place: user_place) }
    end
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

  factory :photo do
    user_place
    user { user_place.user }
    sequence(:s3_key) { |n| "seedkey#{n}" }
  end
end
