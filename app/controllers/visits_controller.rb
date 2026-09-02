class VisitsController < ApplicationController
  before_action :set_user_place

  def create
    visit = @user_place.visits.new(visit_params)

    if visit.valid?
      UserPlace.transaction do
        visit.save!
        attach_photos(visit)
      end
      redirect_to place_path(@user_place), notice: t(".created")
    else
      redirect_to place_path(@user_place), alert: visit.errors.full_messages.to_sentence
    end
  end

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

  def attach_photos(visit)
    @user_place.attach_photos!(params[:photos], user: current_user, visit: visit)
  end
end
