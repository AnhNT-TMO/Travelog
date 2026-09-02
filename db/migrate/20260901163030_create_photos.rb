class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :visit,      foreign_key: true
      t.references :user_place, null: false, foreign_key: true
      t.references :user,       null: false, foreign_key: true

      t.string   :s3_key, null: false
      t.integer  :width
      t.integer  :height
      t.bigint   :byte_size
      t.string   :content_type
      t.datetime :taken_at
      t.float    :exif_lat
      t.float    :exif_lng
      t.boolean  :thumb_ready, null: false, default: false
      t.integer  :position, null: false, default: 0
      t.boolean  :selected_for_google, null: false, default: false

      t.timestamps
    end

    add_index :photos, [ :user_place_id, :position ]
    add_index :photos, [ :visit_id, :position ]
    add_index :photos, :s3_key, unique: true

    add_foreign_key :user_places, :photos, column: :cover_photo_id, on_delete: :nullify
  end
end
