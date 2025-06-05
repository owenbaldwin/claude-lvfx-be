module Api
  module V1
    class AssumptionsController < ApplicationController
      before_action :set_production
      before_action :set_assumption, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/assumptions
      def index
        @assumptions = @production.assumptions
        render json: @assumptions
      end

      # GET /api/v1/productions/:production_id/assumptions/:id
      def show
        render json: @assumption
      end

      # POST /api/v1/productions/:production_id/assumptions
      def create
        production = @current_user.productions.find(params[:production_id])

        @assumption = Assumption.new(assumption_params)
        @assumption.production = production

        if @assumption.save
          render json: @assumption, status: :created
        else
          render json: { errors: @assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/assumptions/:id
      def update
        if @assumption.update(assumption_params)
          render json: @assumption
        else
          render json: { errors: @assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/assumptions/:id
      def destroy
        @assumption.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_assumption
        @assumption = @production.assumptions.find(params[:id])
      end

      def assumption_params
        params.require(:assumption).permit(:name, :description, :complexity_id)
      end
    end
  end
end
