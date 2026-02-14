# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  devise_for :users

  # Admin routes
  namespace :admin do
    post 'ai_logs/model_test', to: 'ai_logs#model_test'
  end

  ActiveAdmin.routes(self)

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up", to: "rails/health#show", as: :rails_health_check

  root to: redirect("admin")

  # API routes
  namespace :api do
    namespace :v1 do
      # Admin user authentication routes
      namespace :admin_users do
        post 'login', to: 'sessions#create'
        post 'refresh', to: 'tokens#refresh'
        post 'logout', to: 'logout#logout'
        post 'logout_all', to: 'logout#logout_all'
      end

      # User authentication routes
      namespace :users do
        post 'login', to: 'sessions#create'
        post 'refresh', to: 'tokens#refresh'
        post 'logout', to: 'logout#logout'
        post 'logout_all', to: 'logout#logout_all'
        get 'credits', to: 'credits#show'
      end

      resources :prompts, only: [] do
        collection do
          post :process_prompt, path: 'process'
        end
      end

      resources :prompt_flows, only: [:create, :show, :update] do
        member do
          post :execute
        end
        resources :executions, only: [:index, :show], controller: 'prompt_flow_executions'
      end
    end
  end

  match "*unmatched", to: "application#route_not_found", via: :all
end
