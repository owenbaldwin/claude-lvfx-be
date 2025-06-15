module Api
  module V1
    class IncentivesController < ApplicationController
      before_action :set_production
      before_action :set_incentive, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/incentives
      def index
        @incentives = @production.incentives.includes(:cost_estimates)
        render json: @incentives, status: :ok
      end

      # GET /api/v1/productions/:production_id/incentives/:id
      def show
        render json: @incentive, status: :ok
      end

      # POST /api/v1/productions/:production_id/incentives
      def create
        @incentive = @production.incentives.new(incentive_params)

        if @incentive.save
          render json: @incentive, status: :created
        else
          render json: { errors: @incentive.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/incentives/:id
      def update
        if @incentive.update(incentive_params)
          render json: @incentive, status: :ok
        else
          render json: { errors: @incentive.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/incentives/:id
      def destroy
        @incentive.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_incentive
        @incentive = @production.incentives.find(params[:id])
      end

      def incentive_params
        params.require(:incentive).permit(:name, :percentage, :description)
      end
    end
  end
end
