module Api
  module V1
    class RegistrationsController < ApplicationController
      skip_before_action :authorize_request, only: :create

      # POST /api/v1/auth/register
      def create
        # Extract registration parameters
        reg_params = params[:registration] || params

        # Create a new user with appropriate attributes
        user = User.new(
          email: reg_params[:email],
          password: reg_params[:password]
        )

        # Handle the name field by splitting it into first_name and last_name
        if reg_params[:name].present?
          name_parts = reg_params[:name].split(' ', 2)
          user.first_name = name_parts[0]
          user.last_name = name_parts[1] || ''
        end

        if user.save
          token = JsonWebToken.encode(user_id: user.id)
          time = Time.now + 24.hours.to_i
          render json: {
            token: token,
            exp: time.strftime("%m-%d-%Y %H:%M"),
            user: {
              id: user.id,
              email: user.email,
              name: "#{user.first_name} #{user.last_name}".strip,
              admin: user.admin
            }
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end
