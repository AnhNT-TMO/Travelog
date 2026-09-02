ENV["RAILS_ENV"] ||= "test"
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

  setup { Rails.application.reload_routes_unless_loaded }

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
