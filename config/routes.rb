# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up", to: "rails/health#show", as: :rails_health_check

  root to: redirect("admin")

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication routes
      namespace :admin_users do
        post 'login', to: 'sessions#create'
        post 'refresh', to: 'tokens#refresh'
        post 'logout', to: 'logout#logout'
        post 'logout_all', to: 'logout#logout_all'
      end

      resources :prompts, only: [] do
        collection do
          post :process_prompt, path: 'process'
        end
      end
    end
  end

  match "*unmatched", to: "application#route_not_found", via: :all
end
