# Backfill trạng thái review từ Google Takeout (plan D13, §12.4).
# Data Portability API không khả dụng ở VN nên Takeout là đường duy nhất.
class CreateTakeoutImports < ActiveRecord::Migration[8.1]
  def change
    create_table :takeout_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string   :filename
      t.integer  :state, null: false, default: 0   # 0 pending 1 parsing 2 needs_review 3 done 4 failed
      t.integer  :reviews_found, null: false, default: 0
      t.integer  :auto_matched,  null: false, default: 0
      t.integer  :needs_review,  null: false, default: 0
      t.text     :error_message

      t.timestamps
    end

    create_table :takeout_candidates do |t|
      t.references :takeout_import, null: false, foreign_key: true
      t.jsonb   :raw, null: false, default: {}     # bản ghi review gốc
      t.string  :source_name
      t.string  :source_address
      t.date    :reviewed_on
      t.integer :rating
      t.text    :body
      t.references :matched_place, foreign_key: { to_table: :places }
      t.integer :match_confidence                  # 0..100
      t.integer :state, null: false, default: 0    # 0 unresolved 1 confirmed 2 skipped

      t.timestamps
    end

    add_index :takeout_candidates, [ :takeout_import_id, :state ]
  end
end
