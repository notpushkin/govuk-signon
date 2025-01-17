Rails.application.routes.draw do
  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
    GovukHealthcheck::SidekiqRedis,
  )

  get "/healthcheck/api-tokens", to: "healthcheck#api_tokens"

  use_doorkeeper do
    controllers authorizations: "signin_required_authorizations"
    skip_controllers :applications, :authorized_applications, :token_info
  end
  post "/oauth/access_token" => "doorkeeper/tokens#create" # compatibility with OAuth v1

  devise_for :users,
             controllers: {
               invitations: "invitations",
               sessions: "sessions",
               passwords: "passwords",
               confirmations: "confirmations",
             }

  devise_scope :user do
    post "/users/invitation/resend/:id" => "invitations#resend", :as => "resend_user_invitation"
    put "/users/confirmation" => "confirmations#update"
    resource :two_step_verification_session,
             only: %i[new create],
             path: "/users/two_step_verification_session",
             controller: "devise/two_step_verification_session"
    resource :two_step_verification,
             only: %i[show update],
             path: "/account/two_step_verification",
             controller: "devise/two_step_verification" do
      member { get :prompt }
    end
  end

  resources :users, except: [:show] do
    member do
      post :unlock
      put :resend_email_change
      delete :cancel_email_change
      get :event_logs
      patch :reset_two_step_verification
      get :require_2sv
    end
  end
  resource :user, only: [:show]

  resource :account, only: [:show]
  namespace :account do
    resource :activity, only: [:show]
    resources :applications, only: %i[show index] do
      resources :permissions, only: [:index]
      resource :signin_permission, only: %i[create destroy] do
        get :delete
      end
    end
    resource :email_password, only: [:show] do
      patch :update_email
      patch :update_password
      put :resend_email_change
      delete :cancel_email_change
    end
    resource :manage_permissions, only: %i[show update]
    resource :role_organisation, only: [:show] do
      patch :update_organisation
      patch :update_role
    end
  end

  resources :batch_invitations, only: %i[new create show] do
    resource :permissions,
             only: %i[new create],
             controller: :batch_invitation_permissions
  end

  resources :organisations, only: %i[index edit update]
  resources :suspensions, only: %i[edit update]
  resources :two_step_verification_exemptions, only: %i[edit update]

  resources :doorkeeper_applications, only: %i[index edit update] do
    member do
      get :users_with_access
    end
    resources :supported_permissions, only: %i[index new create edit update]
  end

  resources :api_users, only: %i[new create index edit update] do
    resources :authorisations, only: %i[new create] do
      member do
        post :revoke
      end
    end
  end

  # Gracefully handle GET on page (e.g. hit refresh) reached by a render to a POST
  match "/users/:id" => redirect("/users/%{id}/edit"), via: :get
  match "/suspensions/:id" => redirect("/users/%{id}/edit"), via: :get

  get "/signin-required" => "root#signin_required"
  get "/privacy-notice" => "root#privacy_notice"

  root to: "root#index"

  put "/user-research-recruitment/update" => "user_research_recruitment#update"
end
