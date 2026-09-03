Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]

  root "collections#index"

  resources :tags, except: [ :show ] do
    member do
      get :places
      patch :share
    end
  end

  get "s/:public_token", to: "public_collections#show", as: :public_collection

  post "places/:place_id/direct_uploads", to: "direct_uploads#create", as: :place_direct_uploads

  resources :places do
    member do
      patch :toggle_priority
    end

    resources :visits, only: [ :create, :destroy ]

    resources :photos, only: [ :create, :destroy ] do
      collection do
        get :download_all
      end

      member do
        get :download
        patch :make_cover
        patch :toggle_google_selection
      end
    end

    resource :review_kit, only: [ :update ] do
      get   :download_photos
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

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
