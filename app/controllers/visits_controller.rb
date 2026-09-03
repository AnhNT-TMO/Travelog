class VisitsController < ApplicationController
  before_action :set_user_place
  before_action :set_visit, only: [ :update, :destroy ]

  def create
    visit = @user_place.visits.new(visit_params)

    if visit.valid?
      UserPlace.transaction do
        visit.save!
        attach_photos(visit)
      end
      redirect_to place_path(@user_place, anchor: "visits"), notice: t(".created")
    else
      redirect_to place_path(@user_place), alert: visit.errors.full_messages.to_sentence
    end
  end

  def update
    @visit.assign_attributes(visit_params)

    if @visit.valid?
      UserPlace.transaction do
        @visit.save!
        remove_photos
        attach_photos(@visit)
      end
      redirect_to place_path(@user_place, anchor: "visit_#{@visit.id}"), notice: t(".updated"), status: :see_other
    else
      redirect_to place_path(@user_place, anchor: "visit_#{@visit.id}"),
                  alert: @visit.errors.full_messages.to_sentence,
                  status: :see_other
    end
  end

  def destroy
    @visit.destroy!
    redirect_to place_path(@user_place, anchor: "visits"), notice: t(".destroyed"), status: :see_other
  end

  private

  def set_user_place
    @user_place = scoped_places.find(params[:place_id])
  end

  def set_visit
    @visit = @user_place.visits.find(params[:id])
  end

  def visit_params
    params.require(:visit).permit(:visited_at, :note)
  end

  def attach_photos(visit)
    @user_place.attach_photos!(params[:photos], user: current_user, visit: visit)
  end

  def remove_photos
    photos = @visit.photos.where(id: Array(params[:remove_photo_ids]))
    @user_place.update!(cover_photo_id: nil) if photos.exists?(id: @user_place.cover_photo_id)
    photos.each(&:destroy!)
  end
end
