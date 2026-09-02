require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LocationProject
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # config/settings/<env>.yml — một file cho mỗi môi trường. Nạp ở ĐÂY chứ
    # không phải trong initializer, vì config/environments/*.rb và
    # config/storage.yml đều cần đọc nó và cả hai chạy trước initializer.
    #
    #   Rails.application.config.settings.cdn_host
    #   Rails.application.config.settings.s3.bucket_originals
    #
    # Thiếu file cho môi trường đang chạy là lỗi lúc boot, không phải nil lúc chạy.
    settings_file = Rails.root.join("config", "settings", "#{Rails.env}.yml")
    unless settings_file.exist?
      raise "Thiếu config/settings/#{Rails.env}.yml — mỗi môi trường phải có một file settings."
    end
    # config_for chỉ bọc OrderedOptions ở tầng ngoài cùng; nhánh lồng nhau vẫn
    # là Hash thường, nên `settings.s3.region` sẽ NoMethodError. Bọc đệ quy để
    # mọi tầng đọc bằng dấu chấm như nhau.
    config.settings = ActiveSupport::OrderedOptions.new.tap do |root|
      deep_wrap = lambda do |value|
        case value
        when Hash  then ActiveSupport::OrderedOptions.new.tap { |o| value.each { |k, v| o[k.to_sym] = deep_wrap.call(v) } }
        when Array then value.map { |v| deep_wrap.call(v) }
        else value
        end
      end

      config_for(settings_file).each { |key, value| root[key.to_sym] = deep_wrap.call(value) }
    end

    # structure.sql thay cho schema.rb: schema.rb không dump được function
    # immutable_unaccent (plan §19.14) lẫn index gist ll_to_earth.
    config.active_record.schema_format = :sql

    # Giờ hiển thị theo Hà Nội, lưu trong DB theo UTC.
    config.time_zone = "Asia/Ho_Chi_Minh"
    config.active_record.default_timezone = :utc

    # i18n — vi mặc định, en là ngôn ngữ đầy đủ thứ hai. Thiếu key ở locale nào
    # thì fallback về vi (bản gốc), không bao giờ hiện key thô ra UI.
    config.i18n.default_locale = :vi
    config.i18n.available_locales = [ :vi, :en ]
    config.i18n.fallbacks = [ :vi ]
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]

    # Thiếu key thì raise ở dev/test để lỗi nổ ngay tại chỗ; production dùng
    # fallback để một key thiếu không làm sập cả trang.
    config.i18n.raise_on_missing_translations = !Rails.env.production?

    # Trang đăng nhập / quên mật khẩu dùng layout riêng — layout "application"
    # render sidebar và cần current_user.
    config.to_prepare do
      Devise::SessionsController.layout "auth"
      Devise::PasswordsController.layout "auth"
    end

    # config.eager_load_paths << Rails.root.join("extras")
  end
end
