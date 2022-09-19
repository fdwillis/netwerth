Rails.application.routes.draw do
  devise_for :users
  

  # devise_for :users
  # devise_for :users, path: '/', path_names: { sign_in: 'auth/login', sign_out: 'auth/logout', sign_up: 'auth/sign-up' }

  # authenticated :user do
    root to: 'home#home'#, as: :authenticated_root
  # end

  # unauthenticated :user do
  #   root 'home#home', as: :unauthenticated_root
  # end

  namespace :api, defaults: { format: 'json' } do
    # VERSION 2 - STRIPE API & DASHBOARD PRODUCT
    namespace :v2 do
      resources :sessions, only: [:create, :destroy], path: '/auth/login'
      resources :stripe_connect_charges, :path => '/charges'
      resources :stripe_connect_customers, :path => '/customers'
      resources :stripe_customers, :path => '/tewcode-customers'
      resources :stripe_connect_invoices, :path => '/invoices'
      resources :stripe_payouts, :path => '/payouts'
      resources :card_pipeline, :path => '/stock-market-debit-card'

      resources :stripe_tokens, only: [:create], :path => '/stripe-tokens'
      resources :stripe_charges, :path => '/stripe-charges'
      resources :stripe_sources, :path => '/stripe-sources'
      post 'stripe-connect-webhooks' => "stripe_connect_webhooks#index", as: :stripeConnectWebhooks
      post 'stripe-webhooks' => "stripe_webhooks#update", as: :stripeWebhooks
      post 'keap-create' => "keap_webhooks#create", as: :createFromKeap
      post 'timekit-reschedule' => "timekit_webhooks#update", as: :updateTimekit
      post 'timekit-create' => "timekit_webhooks#create", as: :createTimekit
      post 'timekit-cancel' => "timekit_webhooks#cancel", as: :cancelTimekit
    end
  end
end