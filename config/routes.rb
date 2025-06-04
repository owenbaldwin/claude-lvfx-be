Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication routes
      post '/auth/login', to: 'authentication#login'
      post '/auth/register', to: 'registrations#create'

      # User routes
      resources :users

      # Production routes with nested resources
      resources :productions do
        resources :users, controller: 'production_users', only: [:index, :create, :destroy]

        resources :characters,           only: [:index, :show, :create, :update, :destroy]
        resources :character_appearances, only: [:index, :show, :create, :update, :destroy]

        # Unsequenced scenes route
        get 'scenes/unsequenced', to: 'scenes#unsequenced'
        put 'scenes/:id/update_unsequenced', to: 'scenes#update_unsequenced'

        # Scripts routes
        resources :scripts, only: [:index, :show, :create] do
          post :parse, on: :member
        end

        # Content structure routes - directly under productions
        resources :sequences do
          resources :scenes do
            resources :action_beats do
              resources :shots
            end
          end
        end
      end
    end
  end
end
