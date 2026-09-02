# Album timeline — mockup D5 / M6. Phase 1 CHỈ xem; xuất PDF là Phase 2 (D11).
class AlbumController < ApplicationController
  def index
    @from = (params[:from].presence || 6.months.ago.to_date).to_date
    @to   = (params[:to].presence || Date.current).to_date

    @visits = Visit.joins(:user_place)
                   .where(user_places: { user_id: current_user.id })
                   .where(visited_at: @from.beginning_of_day..@to.end_of_day)
                   .includes(:photos, user_place: [ :place, :tags ])
                   .chronological
                   .to_a

    @photos_by_visit = photos_by_visit(@visits)

    # Không có bảng trips — group theo tháng là đủ (D17).
    @by_month = @visits.group_by { |visit| visit.visited_at.beginning_of_month }
  end

  private

  # Ảnh thêm từ trang địa điểm (PhotosController) có visit_id NULL — không
  # thuộc lần đến nào, nên album thuần visit-scoped sẽ không bao giờ thấy chúng.
  # Gom mỗi nhóm ảnh rời vào lần đến GẦN NHẤT của địa điểm đó trong khoảng đang
  # xem: @visits sắp xếp mới→cũ nên `delete` lần đầu là lần gần nhất, và ảnh chỉ
  # hiện đúng một lần thay vì lặp lại ở mọi lần đến cùng một chỗ.
  def photos_by_visit(visits)
    by_visit = visits.index_with { |visit| visit.photos.ordered.to_a }
    loose    = loose_photos_by_place(visits)

    visits.each do |visit|
      extras = loose.delete(visit.user_place_id)
      by_visit[visit] += extras if extras
    end

    by_visit
  end

  def loose_photos_by_place(visits)
    return {} if visits.empty?

    current_user.photos
                .where(visit_id: nil, user_place_id: visits.map(&:user_place_id).uniq)
                .ordered
                .group_by(&:user_place_id)
  end
end
