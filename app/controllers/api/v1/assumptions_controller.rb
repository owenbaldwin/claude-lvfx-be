module Api
  module V1
    class AssumptionsController < ApplicationController
      before_action :set_production
      before_action :set_assumption, only: [:show, :update, :destroy]
      before_action :set_shot, only: [:shot_assumptions]

      # GET /api/v1/productions/:production_id/assumptions
      def index
        @assumptions = @production.assumptions
        render json: @assumptions
      end

      # GET /api/v1/productions/:production_id/assumptions/:id
      def show
        render json: @assumption
      end

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/assumptions
      def shot_assumptions
        @assumptions = Assumption.joins(:shot_assumptions)
                                .where(shot_assumptions: { shot_id: @shot.id })
                                .where(production_id: @production.id)
                                .distinct
                                .order(:name)
        render json: @assumptions, status: :ok
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

      def set_shot
        @shot = Shot.find(params[:shot_id])
      end

      def assumption_params
        params.require(:assumption).permit(:name, :description, :category, :complexity_id)
      end
    end
  end
end
