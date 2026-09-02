source "https://rubygems.org"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"

gem "aws-sdk-s3", "~> 1.229", require: false
gem "ferrum_pdf", "~> 3.1"
gem "geocoder", "~> 1.8"
gem "exifr", "~> 1.5"
gem "rubyzip", "~> 3.0", require: "zip"

gem "devise", "~> 4.9"

gem "rails-i18n", "~> 8.0"
gem "devise-i18n", "~> 1.12"
gem "bcrypt", "~> 3.1.7"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false

gem "kamal", require: false

gem "thruster", require: false

gem "image_processing", "~> 2.0"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  gem "dotenv-rails"
  gem "i18n-tasks", "~> 1.0"
  gem "factory_bot_rails"
  gem "faker"

  gem "bundler-audit", require: false

  gem "brakeman", require: false

  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"

  gem "annotaterb"
  gem "letter_opener"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
