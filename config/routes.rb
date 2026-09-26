Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "stories#index"
  resources :stories, only: %i[index show]
  get "about", to: "pages#about", as: :about

  namespace :admin do
    resources :stories, only: :index do
      member do
        post :publish
        post :hold
        post :reject
      end
    end
  end
end
