Rails.application.routes.draw do
  get "politicians/show"
  get "groups/show"
  get "bills/index"
  get "posts/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
  Rails.application.routes.draw do
    root "bills#index"
    resources :bills, only: [:index, :show]
    resources :politicians, only: [:index, :show]
    resources :groups, only: [:index, :show]
    resources :speeches, only: [:index, :show]
  end
end
