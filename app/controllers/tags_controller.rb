class TagsController < ApplicationController
  STATES = %w[wishlist visited all].freeze
  SORTS  = %w[recent priority distance].freeze

  before_action :set_tag, only: [ :edit, :update, :destroy, :share ]

  def index
    @tags = @sidebar_tags
  end

  def new
    @tag = scoped_tags.new
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

  def quick_create
    @tag = scoped_tags.new(tag_params)
    @tag.save

    render :quick_create, status: (@tag.persisted? ? :created : :unprocessable_entity)
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

  def share
    if params[:enabled] == "1"
      @tag.enable_sharing!(share_notes: params[:share_notes] == "1")
    else
      @tag.disable_sharing!
    end

    redirect_back fallback_location: places_tag_path(@tag)
  end

  def places
    @tag       = scoped_tags.find_by!(slug: params[:id])
    @state     = params[:state].presence_in(STATES) || "all"
    @sort      = params[:sort].presence_in(SORTS) || "recent"
    @filter_ids = Array(params[:tags]).reject(&:blank?)
    @center    = nearby_center if @sort == "distance"

    collection = scoped_places.joins(:taggings).where(taggings: { tag_id: @tag.id })
    base       = @filter_ids.any? ? collection.tagged_with_all(@filter_ids) : collection

    @counts = {
      wishlist: base.wishlist.distinct.count,
      visited:  base.visited.distinct.count,
      all:      base.distinct.count
    }

    @filter_tags = sibling_tags(collection)
    @user_places = sorted_places(base)
    @distance_excluded_count = @counts[@state.to_sym] - @user_places.size if @center.present?

    render partial: "shared/place_grid",
           locals: { user_places: @user_places } if turbo_frame_request?
  end

  private

  def set_tag
    @tag = scoped_tags.find_by!(slug: params[:id])
  end

  def sibling_tags(collection)
    tag_ids = Tagging.where(user_place_id: collection.select(:id)).distinct.pluck(:tag_id)
    tag_ids |= @filter_ids.map(&:to_i)

    scoped_tags.where(id: tag_ids - [ @tag.id ]).ordered
  end

  def tag_params
    params.require(:tag).permit(:name, :color, :position)
  end

  def sorted_places(base)
    if @center.present?
      Geo::RadiusQuery.new(
        user:     current_user,
        lat:      @center["lat"],
        lng:      @center["lng"],
        radius_m: Geo::RadiusQuery::MAX_RADIUS_M,
        state:    @state,
        tag_ids:  [ @tag.id ] + @filter_ids
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
end
