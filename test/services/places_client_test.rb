require "test_helper"

class PlacesClientTest < ActiveSupport::TestCase
  test "details có session token luôn gọi Google để kết thúc autocomplete session" do
    client = Google::PlacesClient.new(api_key: "test-key")
    cache = ActiveSupport::Cache::MemoryStore.new
    calls = []
    response = { "id" => "ChIJ-session" }

    with_stubbed_method(Rails, :cache, -> { cache }) do
      with_stubbed_method(client, :get, ->(url, _mask) { calls << url; response }) do
        client.details("ChIJ-session", session_token: "token-one")
        client.details("ChIJ-session", session_token: "token-two")
        client.details("ChIJ-session")
      end
    end

    assert_equal 2, calls.size
    assert_includes calls.first, "sessionToken=token-one"
    assert_includes calls.second, "sessionToken=token-two"
  end
end
