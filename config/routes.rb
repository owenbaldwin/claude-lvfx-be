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
        resources :users, only: [:index]
        resources :users, controller: 'production_users', only: [:index, :create, :destroy]

        resources :characters,           only: [:index, :show, :create, :update, :destroy]
        resources :character_appearances, only: [:index, :show, :create, :update, :destroy] do
          post 'for_action_beat', on: :collection
          post 'for_scene', on: :collection
        end

        resources :complexities
        resources :assumptions
        resources :assets
        resources :fx

        # Cost estimates and incentives
        resources :cost_estimates
        resources :incentives

        # Cost estimate routes for specific resources
        get 'sequences/:sequence_id/cost_estimate', to: 'cost_estimates#show_for_sequence'
        get 'scenes/:scene_id/cost_estimate', to: 'cost_estimates#show_for_scene'
        get 'action_beats/:action_beat_id/cost_estimate', to: 'cost_estimates#show_for_action_beat'
        get 'shots/:shot_id/cost_estimate', to: 'cost_estimates#show_for_shot'
        get 'assets/:asset_id/cost_estimate', to: 'cost_estimates#show_for_asset'
        get 'assumptions/:assumption_id/cost_estimate', to: 'cost_estimates#show_for_assumption'
        get 'fx/:fx_id/cost_estimate', to: 'cost_estimates#show_for_fx'

        # Action beats routes for shot generation
        resources :action_beats, only: [] do
          collection do
            post :generate_shots
            get 'generate_shots/:job_id/status', action: :job_status
            get 'generate_shots/:job_id/results', action: :job_results
          end
        end

        # Production shots route
        get 'shots', to: 'shots#production_shots'

        # Shot assumptions generation route
        post 'shots/generate_assumptions', to: 'shots#generate_assumptions'

        # Unsequenced scenes route
        get 'scenes/unsequenced', to: 'scenes#unsequenced'
        put 'scenes/:id/update_unsequenced', to: 'scenes#update_unsequenced'

        # Scripts routes
        resources :scripts, only: [:index, :show, :create] do
          post :parse, on: :member
          post :parse_with_agents, on: :member
          get 'parse/:job_id/status', action: :parse_status, on: :member
          get 'parse/:job_id/results', action: :parse_results, on: :member
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
                # Assets for this shot
                get 'assets', to: 'assets#shot_assets'
                # Assumptions for this shot
                get 'assumptions', to: 'assumptions#shot_assumptions'
                # FX for this shot
                get 'fx', to: 'fx#shot_fxs'

                resources :shot_assumptions
                resources :shot_assets
                resources :shot_fx
              end
            end
          end
        end

        # Unsequenced action beats routes
        get 'scenes/:scene_id/action_beats/unsequenced', to: 'action_beats#index_unsequenced'
        put 'scenes/:scene_id/action_beats/:id/update_unsequenced', to: 'action_beats#update_unsequenced'
      end
    end
  end
end
