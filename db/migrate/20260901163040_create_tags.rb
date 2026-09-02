class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :slug, null: false
      t.integer :kind, null: false, default: 0
      t.string  :color
      t.integer :position, null: false, default: 0
      t.integer :user_places_count, null: false, default: 0

      t.integer  :visibility, null: false, default: 0
      t.string   :public_token
      t.boolean  :share_notes, null: false, default: false
      t.datetime :shared_at

      t.timestamps
    end

    add_index :tags, [ :user_id, :slug ], unique: true
    add_index :tags, [ :user_id, :kind, :position ]
    add_index :tags, :public_token, unique: true, where: "public_token IS NOT NULL"

    create_table :taggings do |t|
      t.references :tag,        null: false, foreign_key: true
      t.references :user_place, null: false, foreign_key: true

      t.timestamps
    end

    add_index :taggings, [ :tag_id, :user_place_id ], unique: true
  end
end
