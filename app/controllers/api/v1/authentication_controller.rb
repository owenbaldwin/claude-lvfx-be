module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authorize_request, only: :login
      
      # POST /api/v1/auth/login
      def login
        @user = User.find_by_email(params[:email])
        
        if @user&.authenticate(params[:password])
          token = JsonWebToken.encode(user_id: @user.id)
          time = Time.now + 24.hours.to_i
          render json: { 
            token: token, 
            exp: time.strftime("%m-%d-%Y %H:%M"),
            user: {
              id: @user.id,
              email: @user.email,
              first_name: @user.first_name,
              last_name: @user.last_name,
              admin: @user.admin
            }
          }, status: :ok
        else
          render json: { error: 'unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end