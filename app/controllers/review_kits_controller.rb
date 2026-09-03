class ReviewKitsController < ApplicationController
  before_action :set_user_place

  def update
    @user_place.update!(review_body_draft: params.require(:user_place).permit(:review_body_draft)[:review_body_draft])

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to place_path(@user_place) }
    end
  end

  def mark_reviewed
    @user_place.update!(google_review_state: :reviewed, reviewed_at: Time.current)
    redirect_to place_path(@user_place), notice: t(".marked")
  end

  def download_photos
    render json: { files: downloadable(@user_place.photos.selected.ordered) }
  end

  private

  def set_user_place
    @user_place = scoped_places.find(params[:place_id])
  end

  def downloadable(photos)
    photos.filter_map do |photo|
      next unless photo.file.attached?

      { url: rails_blob_path(photo.file, disposition: "attachment"), name: photo.file.filename.to_s }
    end
  end
end
