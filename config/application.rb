require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Travelog
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    settings_file = Rails.root.join("config", "settings", "#{Rails.env}.yml")
    unless settings_file.exist?
      raise "Thiếu config/settings/#{Rails.env}.yml — mỗi môi trường phải có một file settings."
    end
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

    config.active_record.schema_format = :sql

    config.time_zone = "Asia/Ho_Chi_Minh"
    config.active_record.default_timezone = :utc

    config.i18n.default_locale = :vi
    config.i18n.available_locales = [ :vi, :en ]
    config.i18n.fallbacks = [ :vi ]
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]

    config.i18n.raise_on_missing_translations = !Rails.env.production?

    config.to_prepare do
      Devise::SessionsController.layout "auth"
      Devise::PasswordsController.layout "auth"
    end
  end
end
