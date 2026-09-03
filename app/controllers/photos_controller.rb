class PhotosController < ApplicationController
  before_action :set_user_place
  before_action :set_photo, only: [ :destroy, :download, :make_cover, :toggle_google_selection ]

  def create
    @user_place.attach_photos!(params[:photos], user: current_user)

    redirect_to place_path(@user_place), notice: t(".created")
  end

  def destroy
    @user_place.update!(cover_photo_id: nil) if @user_place.cover_photo_id == @photo.id
    @photo.destroy!
    redirect_to place_path(@user_place), notice: t(".destroyed"), status: :see_other
  end

  def download
    raise ActiveRecord::RecordNotFound unless @photo.file.attached?

    redirect_to rails_blob_path(@photo.file, disposition: "attachment")
  end

  def download_all
    render json: { files: downloadable(@user_place.photos.ordered) }
  end

  def make_cover
    @user_place.update!(cover_photo: @photo)
    redirect_to place_path(@user_place)
  end

  def toggle_google_selection
    @photo.update!(selected_for_google: !@photo.selected_for_google?)
    redirect_to place_path(@user_place)
  end

  private

  def set_user_place
    @user_place = scoped_places.find(params[:place_id])
  end

  def set_photo
    @photo = @user_place.photos.find(params[:id])
  end

  def downloadable(photos)
    photos.filter_map do |photo|
      next unless photo.file.attached?

      { url: rails_blob_path(photo.file, disposition: "attachment"), name: photo.file.filename.to_s }
    end
  end
end
