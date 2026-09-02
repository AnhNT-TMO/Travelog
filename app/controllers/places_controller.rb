class PlacesController < ApplicationController
  PER_PAGE = 20

  before_action :set_user_place, only: [ :show, :edit, :update, :destroy, :toggle_priority ]

  def index
    @query = params[:q].to_s.strip
    user_places = scoped_places.with_card_data.order(created_at: :desc, id: :desc)
    user_places = user_places.where(place: Place.name_matching(@query)) if @query.present?

    @total_places = user_places.count
    @total_pages = [ (@total_places.to_f / PER_PAGE).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    @user_places = user_places.offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
    @pagination = pagination

    render partial: "shared/place_grid",
           locals: { user_places: @user_places, pagination: @pagination } if turbo_frame_request?
  end

  def show
    @visits = @user_place.visits.includes(:photos).chronological
    @photos = @user_place.photos.includes(file_attachment: :blob).ordered
  end

  def new
    @user_place = scoped_places.new(status: :wishlist)
    @user_place.build_place
    load_form_tags
  end

  def edit
    load_form_tags
  end

  def create
    @user_place = scoped_places.new(user_place_attributes)
    assign_submitted_place
    @user_place.tag_ids = submitted_tag_ids

    if @user_place.errors.empty? && @user_place.save
      redirect_to place_path(@user_place), notice: t(".created")
    else
      load_form_tags
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @user_place.assign_attributes(user_place_attributes)
    assign_submitted_place
    @user_place.tag_ids = submitted_tag_ids

    if @user_place.errors.empty? && @user_place.save
      redirect_to place_path(@user_place), notice: t(".updated")
    else
      load_form_tags
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user_place.destroy!
    redirect_to root_path, notice: t(".destroyed"), status: :see_other
  end

  def toggle_priority
    @user_place.update!(priority: !@user_place.priority?)
    redirect_back fallback_location: place_path(@user_place)
  end

  private

  def set_user_place
    @user_place = scoped_places.with_card_data.find(params[:id])
  end

  def load_form_tags
    @area_tags = scoped_tags.area.ordered
    @vibe_tags = scoped_tags.where.not(kind: :area).ordered
  end

  def user_place_params
    params.require(:user_place).permit(
      :nickname, :note, :source_url, :my_rating, :priority,
      place_attributes: [ :id, :google_place_id, :display_name, :cached_address, :district, :city, :lat, :lng, :place_type ]
    )
  end

  def user_place_attributes
    user_place_params.except(:place_attributes)
  end

  def submitted_place_attributes
    user_place_params.fetch(:place_attributes, ActionController::Parameters.new)
  end

  def assign_submitted_place
    google_place_id = submitted_place_attributes[:google_place_id].presence

    if google_place_id
      details = Google::PlacesClient.new.details(google_place_id)
      @user_place.place = Google::PlaceUpsert.new(details: details).call
    elsif @user_place.place
      @user_place.place.assign_attributes(submitted_place_attributes.except(:id, :google_place_id))
    else
      @user_place.build_place(submitted_place_attributes.except(:id, :google_place_id))
    end
  rescue Google::PlacesError
    unless @user_place.place
      @user_place.build_place(submitted_place_attributes.except(:id, :google_place_id))
    end
    @user_place.errors.add(:place, t("api.places.unavailable"))
  end

  def submitted_tag_ids
    ids = Array(params.dig(:user_place, :tag_ids)).reject(&:blank?)
    scoped_tags.where(id: ids).ids
  end

  def pagination
    {
      page: @page,
      total_pages: @total_pages,
      path_params: { q: @query.presence }.compact
    }
  end
end
