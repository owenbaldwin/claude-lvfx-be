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
        
        # Scripts routes
        resources :scripts
        
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
