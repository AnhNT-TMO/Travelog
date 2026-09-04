class ReviewKitsController < ApplicationController
  before_action :set_user_place

  def update
    @user_place.update!(review_body_draft: draft_notes)

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_back fallback_location: place_path(@user_place) }
    end
  end

  def rewrite
    notes = draft_notes
    @user_place.update!(review_body_draft: notes)

    return render_draft(error: t(".blank_notes")) if notes.blank?

    render_draft(proposal: Ai::ReviewRewrite.new.call(
      notes: notes,
      place_type: t("place_type.#{@user_place.place.place_type}")
    ))
  rescue Ai::GeminiError => e
    Rails.logger.warn("[review_kit.rewrite] place=#{@user_place.id} #{e.message}")
    render_draft(error: t(".failed"))
  end

  def apply_rewrite
    @user_place.update!(review_body_draft: draft_notes)
    render_draft
  end

  def mark_reviewed
    @user_place.update!(google_review_state: :reviewed, reviewed_at: Time.current)
    redirect_back fallback_location: place_path(@user_place), notice: t(".marked")
  end

  def download_photos
    render json: { files: downloadable(@user_place.photos.selected.ordered) }
  end

  private

  def set_user_place
    @user_place = scoped_places.find(params[:place_id])
  end

  def draft_notes
    params.require(:user_place).permit(:review_body_draft)[:review_body_draft]
  end

  def render_draft(proposal: nil, error: nil)
    render partial: "reviews/draft", formats: [ :html ],
           locals: { user_place: @user_place, proposal: proposal, error: error },
           status: error ? :unprocessable_entity : :ok
  end

  def downloadable(photos)
    photos.filter_map do |photo|
      next unless photo.file.attached?

      { url: rails_blob_path(photo.file, disposition: "attachment"), name: photo.file.filename.to_s }
    end
  end
end
