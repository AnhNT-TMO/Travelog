class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :user_place, null: false, foreign_key: true
      t.date     :visited_on, null: false
      t.text     :note
      t.integer  :photos_count, null: false, default: 0
      t.integer  :source, null: false, default: 0

      t.timestamps
    end

    add_index :visits, [ :user_place_id, :visited_on ], order: { visited_on: :desc }
  end
end
