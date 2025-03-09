module Api
  module V1
    class ProductionsController < ApplicationController
      before_action :set_production, only: [:show, :update, :destroy]
      
      # GET /api/v1/productions
      def index
        @productions = @current_user.productions
        render json: @productions, status: :ok
      end
      
      # GET /api/v1/productions/{id}
      def show
        render json: @production, status: :ok
      end
      
      # POST /api/v1/productions
      def create
        @production = Production.new(production_params)
        
        if @production.save
          # Add current user as a production owner
          ProductionUser.create(user: @current_user, production: @production, role: 'owner')
          render json: @production, status: :created
        else
          render json: { errors: @production.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/productions/{id}
      def update
        if @production.update(production_params)
          render json: @production, status: :ok
        else
          render json: { errors: @production.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/productions/{id}
      def destroy
        @production.destroy
        head :no_content
      end
      
      private
      
      def set_production
        @production = @current_user.productions.find(params[:id])
      end
      
      def production_params
        params.permit(:title, :description, :start_date, :end_date, :status)
      end
    end
  end
end