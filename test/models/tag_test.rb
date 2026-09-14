require "test_helper"

class TagTest < ActiveSupport::TestCase
  setup { @user = create(:user) }

  test "tên khác dấu là hai tag khác nhau" do
    pho_street = @user.tags.create!(name: "Phố")
    pho_soup   = @user.tags.create!(name: "Phở")

    assert_equal "pho",   pho_street.slug
    assert_equal "pho-2", pho_soup.slug
  end

  test "tên trùng không phân biệt hoa thường bị chặn" do
    @user.tags.create!(name: "Phở")
    duplicate = @user.tags.create(name: "  phở  ")

    assert_not duplicate.persisted?
    assert_includes duplicate.errors.attribute_names, :name
  end

  test "hai người dùng có thể dùng cùng một tên tag" do
    @user.tags.create!(name: "Hồ Tây")

    assert create(:user).tags.create(name: "Hồ Tây").persisted?
  end

  test "đổi tên không đổi slug" do
    tag = @user.tags.create!(name: "Hồ Tây")
    tag.update!(name: "Tây Hồ")

    assert_equal "ho-tay", tag.slug
  end
end
