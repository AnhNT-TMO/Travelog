require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "một khách chưa đăng nhập bị từ chối chứ không nổ NameError" do
    assert_reject_connection { connect }
  end

  test "Warden cung cấp current_user cho connection" do
    user = create(:user)
    cookies.signed[:dummy] = "x"

    connect env: { "warden" => Struct.new(:user).new(user) }

    assert_equal user, connection.current_user
  end
end
