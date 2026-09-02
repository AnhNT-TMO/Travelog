# places = dữ liệu KHÁCH QUAN về một địa điểm, dùng chung mọi user, dedupe theo
# google_place_id. Không bao giờ nhét trạng thái của người dùng vào đây — chỗ đó
# là user_places (plan §5.1).
class CreatePlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :places do |t|
      t.string  :google_place_id
      t.string  :display_name, null: false
      t.integer :place_type, null: false, default: 0    # 0 cafe 1 food 2 sight 3 other

      # toạ độ — float8 vì earthdistance nhận float8
      t.float   :lat
      t.float   :lng
      t.integer :coords_source, null: false, default: 0 # 0 google 1 exif 2 manual

      # snapshot từ Google, refresh khi cần (điều khoản cache: plan §10.4)
      t.string   :cached_name
      t.string   :cached_address
      t.string   :city
      t.string   :district
      t.jsonb    :cached_payload, null: false, default: {}
      t.datetime :cached_at

      t.timestamps
    end

    add_index :places, :google_place_id, unique: true, where: "google_place_id IS NOT NULL"
    add_index :places, :district

    execute <<~SQL
      CREATE INDEX index_places_on_earth
        ON places USING gist (ll_to_earth(lat, lng))
        WHERE lat IS NOT NULL AND lng IS NOT NULL;

      CREATE INDEX index_places_on_display_name_trgm
        ON places USING gin (lower(immutable_unaccent(display_name)) gin_trgm_ops);
    SQL
  end
end
