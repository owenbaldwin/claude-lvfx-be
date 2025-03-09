module Api
  module V1
    class ProductionUsersController < ApplicationController
      before_action :set_production
      
      # GET /api/v1/productions/{production_id}/users
      def index
        @production_users = @production.production_users
        render json: @production_users, status: :ok
      end
      
      # POST /api/v1/productions/{production_id}/users
      def create
        user = User.find_by(email: params[:email])
        
        if user.nil?
          render json: { error: 'User not found' }, status: :not_found
          return
        end
        
        @production_user = ProductionUser.new(
          user: user,
          production: @production,
          role: params[:role]
        )
        
        if @production_user.save
          render json: @production_user, status: :created
        else
          render json: { errors: @production_user.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/productions/{production_id}/users/{id}
      def destroy
        @production_user = @production.production_users.find_by(user_id: params[:id])
        @production_user.destroy
        head :no_content
      end
      
      private
      
      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end
    end
  end
end