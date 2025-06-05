module Api
  module V1
    class ComplexitiesController < ApplicationController
      before_action :set_complexity, only: [:show, :update, :destroy]

      # GET /api/v1/complexities
      def index
        @complexities = Complexity.all
        render json: @complexities
      end

      # GET /api/v1/complexities/:id
      def show
        render json: @complexity
      end

      # POST /api/v1/complexities
      def create
        @complexity = Complexity.new(complexity_params)

        if @complexity.save
          render json: @complexity, status: :created
        else
          render json: { errors: @complexity.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/complexities/:id
      def update
        if @complexity.update(complexity_params)
          render json: @complexity
        else
          render json: { errors: @complexity.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/complexities/:id
      def destroy
        @complexity.destroy
        head :no_content
      end

      private

      def set_complexity
        @complexity = Complexity.find(params[:id])
      end

      def complexity_params
        params.require(:complexity).permit(:level, :description, :production_id, :user_id)
      end
    end
  end
end
