class User < ApplicationRecord
  # Plan §14.2 — registration công khai bị tắt ở routes; tạo user bằng console/seed.
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :trackable

  has_many :user_places,     dependent: :destroy
  has_many :tags,            dependent: :destroy
  has_many :photos,          dependent: :destroy
  has_many :takeout_imports, dependent: :destroy
  has_many :places, through: :user_places

  normalizes :email, with: ->(value) { value.strip.downcase }

  # tên hiển thị ở .side-foot / .avatar; fallback về phần trước @ của email
  def label = display_name.presence || email.split("@").first

  def initials = label.split(/[\s._-]+/).first(2).map { |part| part[0] }.join.upcase
end
