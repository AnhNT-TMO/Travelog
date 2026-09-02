require "active_support/core_ext/integer/time"

# Staging = production với log rộng hơn và error page đầy đủ.
# Mọi khác biệt còn lại nằm ở config/settings/staging.yml, không nằm ở đây —
# nếu file này bắt đầu phân nhánh theo nghiệp vụ thì đó là dấu hiệu sai chỗ.
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  # Khác production: staging là nơi để đọc lỗi, không phải nơi để giấu lỗi.
  config.consider_all_requests_local = true

  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Ảnh gốc lên S3 (bucket staging, khác production — xem settings/staging.yml).
  config.active_storage.service = :originals

  config.assume_ssl = true
  config.force_ssl  = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "debug")

  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = true

  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue

  config.action_mailer.default_url_options = {
    host:     config.settings.app_host,
    protocol: config.settings.app_protocol
  }
  config.action_mailer.default_options = { from: config.settings.mailer_sender }
  config.action_mailer.raise_delivery_errors = true

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
