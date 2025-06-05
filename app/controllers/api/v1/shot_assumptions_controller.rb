module Api
  module V1
    class ShotAssumptionsController < ApplicationController
      before_action :set_parent_shot
      before_action :set_shot_assumption, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/…/shots/:shot_id/shot_assumptions
      def index
        @shot_assumptions = @shot.shot_assumptions
        render json: @shot_assumptions
      end

      # GET /api/v1/productions/:production_id/…/shots/:shot_id/shot_assumptions/:id
      def show
        render json: @shot_assumption
      end

      # POST /api/v1/productions/:production_id/…/shots/:shot_id/shot_assumptions
      def create
        @shot_assumption = @shot.shot_assumptions.build(shot_assumption_params)
        if @shot_assumption.save
          render json: @shot_assumption, status: :created
        else
          render json: { errors: @shot_assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/…/shots/:shot_id/shot_assumptions/:id
      def update
        if @shot_assumption.update(shot_assumption_params)
          render json: @shot_assumption
        else
          render json: { errors: @shot_assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/…/shots/:shot_id/shot_assumptions/:id
      def destroy
        @shot_assumption.destroy
        head :no_content
      end

      private

      def set_parent_shot
        @shot = Shot.find(params[:shot_id])
      end

      def set_shot_assumption
        @shot_assumption = @shot.shot_assumptions.find(params[:id])
      end

      def shot_assumption_params
        # We only need assumption_id here; shot_id is inferred
        params.require(:shot_assumption).permit(:assumption_id)
      end
    end
  end
end
