# Ảnh của một địa điểm — thêm ngoài luồng check-in, chọn cover, chọn ảnh gửi
# kèm review Google.
class PhotosController < ApplicationController
  before_action :set_user_place
  before_action :set_photo, only: [ :destroy, :make_cover, :toggle_google_selection ]

  # params[:photos] là mảng signed id của blob — ảnh đã lên S3 bằng direct
  # upload trước khi form được submit.
  def create
    @user_place.attach_photos!(params[:photos], user: current_user)

    redirect_to place_path(@user_place), notice: t(".created")
  end

  def destroy
    @user_place.update!(cover_photo_id: nil) if @user_place.cover_photo_id == @photo.id
    @photo.destroy!
    redirect_to place_path(@user_place), notice: t(".destroyed"), status: :see_other
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
end
