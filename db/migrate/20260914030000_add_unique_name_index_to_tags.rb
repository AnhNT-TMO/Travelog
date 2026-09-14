class AddUniqueNameIndexToTags < ActiveRecord::Migration[8.1]
  def change
    add_index :tags,
              "user_id, lower(name)",
              unique: true,
              name:   "index_tags_on_user_id_and_lower_name"
  end
end
