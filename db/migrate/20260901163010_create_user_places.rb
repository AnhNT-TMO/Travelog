# user_places = quan hệ CHỦ QUAN của một người với một place: trạng thái, tag,
# note, ảnh. Mọi query phải bắt đầu từ current_user (plan §14.3).
class CreateUserPlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :user_places do |t|
      t.references :user,  null: false, foreign_key: true
      t.references :place, null: false, foreign_key: true

      t.integer  :status, null: false, default: 0       # 0 wishlist 1 visited
      t.string   :nickname                              # tên người dùng tự đặt
      t.text     :note
      t.integer  :my_rating                             # 1..5, nội bộ
      t.boolean  :priority, null: false, default: false
      t.string   :source_url                            # link TikTok/Facebook

      t.datetime :first_visited_at
      t.datetime :last_visited_at
      t.integer  :visits_count, null: false, default: 0
      t.integer  :photos_count, null: false, default: 0
      t.bigint   :cover_photo_id                        # FK thêm ở migration photos

      t.integer  :google_review_state, null: false, default: 0 # 0 unknown 1 not_reviewed 2 reviewed
      t.datetime :reviewed_at
      t.text     :review_body_draft

      t.timestamps
    end

    add_index :user_places, [ :user_id, :place_id ], unique: true
    add_index :user_places, [ :user_id, :status ]
    add_index :user_places, [ :user_id, :last_visited_at ], order: { last_visited_at: :desc }
    add_index :user_places, [ :user_id, :google_review_state ]
    add_index :user_places, :cover_photo_id
  end
end
