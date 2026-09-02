# Check-in — mockup M4 (bottom sheet). Mỗi lần đến là một record riêng với ảnh
# của chính lần đó; không gộp ảnh vào địa điểm (plan §5.1).
class VisitsController < ApplicationController
  before_action :set_user_place

  def create
    visit = @user_place.visits.new(visit_params)

    if visit.save
      attach_photos(visit)
      redirect_to place_path(@user_place), notice: t(".created")
    else
      redirect_to place_path(@user_place), alert: visit.errors.full_messages.to_sentence
    end
  end

  # destroy chứ không delete_all: callback after_commit của Visit là thứ giữ
  # visits_count / first_visited_at / last_visited_at đúng.
  def destroy
    @user_place.visits.find(params[:id]).destroy!
    redirect_to place_path(@user_place), notice: t(".destroyed"), status: :see_other
  end

  private

  def set_user_place
    @user_place = scoped_places.find(params[:place_id])
  end

  def visit_params
    params.require(:visit).permit(:visited_at, :note, :companions)
  end

  # params[:photos] là mảng signed id của blob, không phải file: trình duyệt đã
  # PUT thẳng lên S3 trước khi submit form (direct upload).
  def attach_photos(visit)
    @user_place.attach_photos!(params[:photos], user: current_user, visit: visit)
  end
end
