# Bộ kit review Google — plan §12.3.
# KHÔNG có API đăng review và automation vi phạm ToS: app chỉ soạn nội dung,
# gói ảnh, mở deep link, rồi để người dùng tự tick "đã đăng".
class ReviewKitsController < ApplicationController
  before_action :set_user_place

  # Autosave draft từ textarea (debounce ở phía Stimulus).
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

  # Ảnh gốc chứ không phải bản 1600px: Lambda thumbnailer chưa tồn tại nên
  # derivative chưa được ghi ở đâu cả (HANDOFF mục 5).
  def photos_zip
    photos = @user_place.photos.selected.ordered.select { |photo| photo.file.attached? }

    if photos.empty?
      redirect_to place_path(@user_place), alert: t(".nothing_selected")
      return
    end

    send_data zip_for(photos),
              filename: "#{Vietnamese.slugify(@user_place.label)}-review.zip",
              type: "application/zip"
  end

  private

  def set_user_place
    @user_place = scoped_places.find(params[:place_id])
  end

  def zip_for(photos)
    Zip::OutputStream.write_buffer do |zip|
      photos.each_with_index do |photo, index|
        zip.put_next_entry(format("%02d-%s", index + 1, photo.file.filename.to_s))
        zip.write(photo.file.download)
      end
    end.string
  end
end
