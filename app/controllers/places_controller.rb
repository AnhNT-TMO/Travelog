# Chi tiết + CRUD địa điểm — mockup D3 / M3 / M5.
# Panel bên phải (desktop) và trang riêng (mobile) dùng CHUNG một partial.
class PlacesController < ApplicationController
  before_action :set_user_place, only: [ :show, :edit, :update, :destroy, :toggle_priority ]

  def index
    @query = params[:q].to_s.strip
    @user_places = scoped_places.with_card_data.order(created_at: :desc)
    @user_places = @user_places.where(place: Place.name_matching(@query)) if @query.present?

    render partial: "shared/place_grid",
           locals: { user_places: @user_places } if turbo_frame_request?
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

  # Chỉ xoá quan hệ của tôi với địa điểm. Place là dữ liệu khách quan, dùng
  # chung giữa nhiều user — xoá nó sẽ cắt dữ liệu của người khác.
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
      :nickname, :note, :status, :source_url, :my_rating, :priority,
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

  # Tag phải lọc lại qua scoped_tags: id trong form là dữ liệu người dùng gửi
  # lên, gán thẳng sẽ cho gắn tag của người khác.
  def submitted_tag_ids
    ids = Array(params.dig(:user_place, :tag_ids)).reject(&:blank?)
    scoped_tags.where(id: ids).ids
  end
end
