# Không còn webhook từ Lambda về Rails (chủ dự án chốt 02.09.2026), nên không
# ai ghi cột này nữa. Một cột boolean vĩnh viễn false là cái bẫy: người đọc code
# sau này sẽ tin nó có nghĩa.
#
# Thay vào đó, trạng thái "ảnh đã sẵn sàng chưa" được trả lời bằng chính HTTP:
# derivative có thì hiện, chưa có thì onerror rơi về ảnh gốc.
class RemoveThumbReadyFromPhotos < ActiveRecord::Migration[8.1]
  def change
    remove_column :photos, :thumb_ready, :boolean, null: false, default: false
  end
end
