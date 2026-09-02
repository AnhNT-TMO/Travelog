ENV["RAILS_ENV"] ||= "test"
# Cấu hình của test nằm ở config/settings/test.yml và cố tình KHÔNG đọc ENV:
# docker compose bơm .env vào process nên biến đã tồn tại trước khi Ruby chạy,
# và test sẽ phụ thuộc .env của từng máy.
require_relative "../config/environment"
require "rails/test_help"

module TestMethodStub
  def with_stubbed_method(object, name, replacement)
    singleton_class = object.singleton_class
    original = object.method(name)
    singleton_class.define_method(name, replacement)
    yield
  ensure
    singleton_class.define_method(name, original)
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    include FactoryBot::Syntax::Methods
    include TestMethodStub
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include TestMethodStub

  # Devise.mappings chỉ được populate khi routes đã draw. sign_in gọi trước
  # request đầu tiên sẽ báo "Could not find a valid mapping" nếu thiếu dòng này.
  setup { Rails.application.reload_routes_unless_loaded }

  # allow_browser versions: :modern trả 403 cho request không có User-Agent.
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36".freeze

  def default_headers = { "User-Agent" => MODERN_UA }

  %i[get post patch put delete].each do |verb|
    define_method(verb) do |path, **options|
      options[:headers] = default_headers.merge(options[:headers] || {})
      super(path, **options)
    end
  end
end
