class RemoveThumbReadyFromPhotos < ActiveRecord::Migration[8.1]
  def change
    remove_column :photos, :thumb_ready, :boolean, null: false, default: false
  end
end
