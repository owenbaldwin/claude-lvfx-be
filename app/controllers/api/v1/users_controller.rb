module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :authorize_request, only: :create
      before_action :set_user, only: [:show, :update, :destroy]
      
      # GET /api/v1/users
      def index
        @users = User.all
        render json: @users, status: :ok
      end
      
      # GET /api/v1/users/{id}
      def show
        render json: @user, status: :ok
      end
      
      # POST /api/v1/users
      def create
        @user = User.new(user_params)
        
        if @user.save
          render json: @user, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/users/{id}
      def update
        if @user.update(user_params)
          render json: @user, status: :ok
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/users/{id}
      def destroy
        @user.destroy
        head :no_content
      end
      
      private
      
      def set_user
        @user = User.find(params[:id])
      end
      
      def user_params
        params.permit(:email, :password, :password_confirmation, :first_name, :last_name)
      end
    end
  end
end