# Mỗi lần đến là một bản ghi riêng. Không có bảng trips (plan D17).
class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :user_place, null: false, foreign_key: true
      t.datetime :visited_at, null: false
      t.text     :note
      t.string   :companions
      t.integer  :photos_count, null: false, default: 0
      t.integer  :source, null: false, default: 0   # 0 manual 1 exif_import

      t.timestamps
    end

    add_index :visits, [ :user_place_id, :visited_at ], order: { visited_at: :desc }
  end
end
