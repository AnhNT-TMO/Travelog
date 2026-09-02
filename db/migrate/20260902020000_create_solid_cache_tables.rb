# Solid Cache nằm chung database với dữ liệu app — chủ dự án chốt gộp bốn
# database thành một (RDS nhỏ, lượng dữ liệu không đáng để tách).
# Bảng lấy nguyên từ db/cache_schema.rb trước khi file đó bị xoá.
class CreateSolidCacheTables < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries do |t|
      t.binary   :key,       null: false
      t.binary   :value,     null: false
      t.bigint   :key_hash,  null: false
      t.integer  :byte_size, null: false
      t.datetime :created_at, null: false

      t.index :byte_size
      t.index :key_hash, unique: true
      t.index [ :key_hash, :byte_size ]
    end
  end
end
