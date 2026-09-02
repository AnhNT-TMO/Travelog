Rails.application.routes.draw do
  # Registration công khai bị tắt (app nội bộ) — tạo user bằng console hoặc seed.
  devise_for :users, skip: [ :registrations ]

  root "collections#index"

  resources :tags, except: [ :show ] do
    member do
      get :places   # /tags/:id/places?state=&vibe[]=
      patch :share  # bật/tắt link chia sẻ read-only
    end
  end

  # Public read-only, KHÔNG qua authenticate_user! — plan §23.
  # find_by! → RecordNotFound → 404 khi token sai hoặc share đã tắt.
  get "s/:public_token", to: "public_collections#show", as: :public_collection

  # Thực chất là user_places; giữ URL /places cho gọn.
  post "places/:place_id/direct_uploads", to: "direct_uploads#create", as: :place_direct_uploads

  resources :places do
    member do
      patch :toggle_priority
    end

    resources :visits, only: [ :create, :destroy ]

    resources :photos, only: [ :create, :destroy ] do
      member do
        patch :make_cover
        patch :toggle_google_selection
      end
    end

    resource :review_kit, only: [ :update ] do
      get   :photos_zip
      patch :mark_reviewed
    end
  end

  get "nearby", to: "nearby#index"
  get "album",  to: "album#index"
  get "me",     to: "account#show"

  namespace :api do
    get "places/autocomplete", to: "places#autocomplete"
    get "places/details",      to: "places#details"
  end

  # ---------------------------------------------------------------------------
  # CHƯA LÀM — plan §6 khai báo thêm các route dưới đây. Chỉ mở route khi
  # controller tương ứng đã tồn tại, đừng khai báo trước rồi để 500.
  #
  #   resources :takeout_imports, only: [:index, :new, :create, :show] do
  #     member { patch :resolve }
  #   end
  # ---------------------------------------------------------------------------

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
