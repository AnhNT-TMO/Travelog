class ReviewsController < ApplicationController
  def index
    @user_places = scoped_places.needing_google_review.with_card_data.order(:id).to_a
    @reviewed_count = scoped_places.visited.review_reviewed.count

    @position = selected_position
    @user_place = @user_places[@position - 1] if @position.positive?
    @next_user_place = @user_places[@position] if @position.positive?
    @photos = @user_place ? @user_place.photos.includes(file_attachment: :blob).ordered : []
  end

  private

  def selected_position
    return 0 if @user_places.empty?

    requested = @user_places.index { |user_place| user_place.id.to_s == params[:place].to_s }
    (requested || 0) + 1
  end
end
