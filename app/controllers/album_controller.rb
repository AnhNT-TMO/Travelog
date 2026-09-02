class AlbumController < ApplicationController
  def index
    @from = parsed_date(params[:from], 6.months.ago.to_date)
    @to   = parsed_date(params[:to], Date.current)

    @visits = Visit.joins(:user_place)
                   .where(user_places: { user_id: current_user.id })
                   .where(visited_at: @from.beginning_of_day..@to.end_of_day)
                   .includes(:photos, user_place: :place)
                   .chronological
                   .to_a

    @photos_by_visit = photos_by_visit(@visits)

    @by_month = @visits.group_by { |visit| visit.visited_at.beginning_of_month }
  end

  private

  def parsed_date(value, default)
    return default if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    default
  end

  def photos_by_visit(visits)
    by_visit = visits.index_with { |visit| visit.photos.to_a }
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
