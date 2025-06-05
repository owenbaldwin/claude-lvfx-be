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

        resources :complexities
        resources :assumptions
        resources :assets
        resources :fx

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
            # Character routes for scenes
            get 'characters', to: 'characters#scene_characters'

            resources :action_beats do
              # Character routes for action beats
              get 'characters', to: 'characters#action_beat_characters'

              resources :shots do
                resources :shot_assumptions
                resources :shot_assets
                resources :shot_fx
              end
            end
          end
        end

        # Unsequenced action beats route
        put 'scenes/:scene_id/action_beats/:id/update_unsequenced', to: 'action_beats#update_unsequenced'
      end
    end
  end
end
