# Danh sách theo tag (mockup D2 / M2) + quản lý tag và bật/tắt link chia sẻ.
class TagsController < ApplicationController
  STATES = %w[wishlist visited all].freeze
  SORTS  = %w[recent priority distance].freeze

  before_action :set_tag, only: [ :edit, :update, :destroy, :share ]

  # Trang "Quản lý tag" — link `.act` ở trang chủ trong mockup D1.
  def index
    @area_tags = @sidebar_tags.select(&:area?)
    @vibe_tags = @sidebar_tags.reject(&:area?)
  end

  def new
    @tag = scoped_tags.new(kind: params[:kind].presence_in(Tag.kinds.keys) || "area")
  end

  def edit
  end

  def create
    @tag = scoped_tags.new(tag_params)

    if @tag.save
      redirect_to tags_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @tag.update(tag_params)
      redirect_to tags_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy!
    redirect_to tags_path, notice: t(".destroyed"), status: :see_other
  end

  # Bật share sinh token MỚI mỗi lần, nên link cũ chết vĩnh viễn sau khi tắt —
  # đó là hành vi cố ý, đừng "sửa" thành giữ nguyên token (plan §23.2).
  def share
    if params[:enabled] == "1"
      @tag.enable_sharing!(share_notes: params[:share_notes] == "1")
    else
      @tag.disable_sharing!
    end

    redirect_back fallback_location: places_tag_path(@tag)
  end

  def places
    @tag      = scoped_tags.find_by!(slug: params[:id])
    @state    = params[:state].presence_in(STATES) || "wishlist"
    @sort     = params[:sort].presence_in(SORTS) || "recent"
    @vibe_ids = Array(params[:vibe]).reject(&:blank?)

    base = scoped_places.joins(:taggings).where(taggings: { tag_id: @tag.id })
    base = base.tagged_with_all(@vibe_ids) if @vibe_ids.any?

    @counts = {
      wishlist: base.wishlist.distinct.count,
      visited:  base.visited.distinct.count,
      all:      base.distinct.count
    }

    @vibe_tags = scoped_tags.vibe.ordered
    @user_places = sorted_places(base)

    render partial: "shared/place_grid",
           locals: { user_places: @user_places } if turbo_frame_request?
  end

  private

  def set_tag
    @tag = scoped_tags.find_by!(slug: params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name, :kind, :color, :position)
  end

  # .distinct + ORDER BY distance_m lỗi ở Postgres nếu distance_m không nằm
  # trong select list — sort theo khoảng cách đi qua Geo::RadiusQuery, không
  # viết lại SQL ở đây (plan §19.3).
  def sorted_places(base)
    if @sort == "distance" && nearby_center.present?
      Geo::RadiusQuery.new(
        user:     current_user,
        lat:      nearby_center["lat"],
        lng:      nearby_center["lng"],
        radius_m: Geo::RadiusQuery::MAX_RADIUS_M,
        state:    @state,
        tag_ids:  [ @tag.id ] + @vibe_ids
      ).call.to_a
    else
      base.for_state(@state).with_card_data.order(sort_clause).distinct
    end
  end

  def sort_clause
    case @sort
    when "priority" then { priority: :desc, created_at: :desc }
    else { created_at: :desc }
    end
  end

  # Tâm gần nhất người dùng đã chọn ở trang Quanh đây. Không có tâm thì không
  # sắp theo khoảng cách được — trang sẽ nói ra thay vì im lặng đổi thứ tự.
  def nearby_center
    session[NearbyController::SESSION_CENTER_KEY]
  end
end
