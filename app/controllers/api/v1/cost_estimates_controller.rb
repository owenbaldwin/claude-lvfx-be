module Api
  module V1
    class CostEstimatesController < ApplicationController
      before_action :set_production
      before_action :set_cost_estimate, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/cost_estimates
      def index
        @cost_estimates = @production.cost_estimates.includes(:incentive, :sequence, :scene, :action_beat, :shot, :asset, :fx, :assumption)
        render json: @cost_estimates, status: :ok
      end

      # GET /api/v1/productions/:production_id/cost_estimates/:id
      def show
        render json: @cost_estimate, status: :ok
      end

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/cost_estimate
      def show_for_sequence
        @sequence = @production.sequences.find(params[:sequence_id])
        @cost_estimate = @sequence.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this sequence' }, status: :not_found
        end
      end

      # GET /api/v1/productions/:production_id/scenes/:scene_id/cost_estimate
      def show_for_scene
        @scene = @production.scenes.find(params[:scene_id])
        @cost_estimate = @scene.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this scene' }, status: :not_found
        end
      end

      # GET /api/v1/productions/:production_id/action_beats/:action_beat_id/cost_estimate
      def show_for_action_beat
        @action_beat = @production.action_beats.find(params[:action_beat_id])
        @cost_estimate = @action_beat.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this action beat' }, status: :not_found
        end
      end

      # GET /api/v1/productions/:production_id/shots/:shot_id/cost_estimate
      def show_for_shot
        @shot = @production.shots.find(params[:shot_id])
        @cost_estimate = @shot.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this shot' }, status: :not_found
        end
      end

      # GET /api/v1/productions/:production_id/assets/:asset_id/cost_estimate
      def show_for_asset
        @asset = @production.assets.find(params[:asset_id])
        @cost_estimate = @asset.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this asset' }, status: :not_found
        end
      end

      # GET /api/v1/productions/:production_id/assumptions/:assumption_id/cost_estimate
      def show_for_assumption
        @assumption = @production.assumptions.find(params[:assumption_id])
        @cost_estimate = @assumption.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this assumption' }, status: :not_found
        end
      end

      # GET /api/v1/productions/:production_id/fx/:fx_id/cost_estimate
      def show_for_fx
        @fx = @production.fxs.find(params[:fx_id])
        @cost_estimate = @fx.cost_estimates.first

        if @cost_estimate
          render json: @cost_estimate, status: :ok
        else
          render json: { error: 'Cost estimate not found for this fx' }, status: :not_found
        end
      end

      # POST /api/v1/productions/:production_id/cost_estimates
      def create
        @cost_estimate = @production.cost_estimates.new(cost_estimate_params)

        if @cost_estimate.save
          render json: @cost_estimate, status: :created
        else
          render json: { errors: @cost_estimate.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/cost_estimates/:id
      def update
        if @cost_estimate.update(cost_estimate_params)
          render json: @cost_estimate, status: :ok
        else
          render json: { errors: @cost_estimate.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/cost_estimates/:id
      def destroy
        @cost_estimate.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_cost_estimate
        @cost_estimate = @production.cost_estimates.find(params[:id])
      end

      def cost_estimate_params
        params.require(:cost_estimate).permit(
          :incentive_id, :sequence_id, :scene_id, :action_beat_id, :shot_id,
          :asset_id, :fx_id, :assumption_id, :rate, :margin, :gross, :net,
          :gross_average, :net_average
        )
      end
    end
  end
end
