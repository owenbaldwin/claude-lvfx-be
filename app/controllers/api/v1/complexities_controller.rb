module Api
  module V1
    class ComplexitiesController < ApplicationController
      before_action :set_production
      before_action :set_complexity, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/complexities
      def index
        @complexities = @production.complexities
        render json: @complexities
      end

      # GET /api/v1/productions/:production_id/complexities/:id
      def show
        render json: @complexity
      end

      # POST /api/v1/productions/:production_id/complexities
      def create
        production = @current_user.productions.find(params[:production_id])

        @complexity = Complexity.new(complexity_params)
        @complexity.production = production
        @complexity.user = @current_user

        if @complexity.save
          render json: @complexity, status: :created
        else
          render json: { errors: @complexity.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/complexities/:id
      def update
        if @complexity.update(complexity_params)
          render json: @complexity
        else
          render json: { errors: @complexity.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/complexities/:id
      def destroy
        @complexity.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_complexity
        @complexity = @production.complexities.find(params[:id])
      end

      def complexity_params
        params.require(:complexity).permit(:key, :level, :description)
      end
    end
  end
end
