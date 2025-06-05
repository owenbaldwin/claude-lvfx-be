module Api
  module V1
    class ShotAssetsController < ApplicationController
      before_action :set_parent_shot
      before_action :set_shot_asset, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/shot_assets
      def index
        @shot_assets = @shot.shot_assets
        render json: @shot_assets
      end

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/shot_assets/:id
      def show
        render json: @shot_asset
      end

      # POST /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/shot_assets
      def create
        # Build via the parent shot so shot_id is set automatically
        @shot_asset = @shot.shot_assets.build(shot_asset_params)

        if @shot_asset.save
          render json: @shot_asset, status: :created
        else
          render json: { errors: @shot_asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/shot_assets/:id
      def update
        if @shot_asset.update(shot_asset_params)
          render json: @shot_asset
        else
          render json: { errors: @shot_asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/shot_assets/:id
      def destroy
        @shot_asset.destroy
        head :no_content
      end

      private

      # Load the parent shot (using only shot_id, but you could also verify it belongs
      # to the correct production/sequence/scene/action_beat if you want strict checks).
      def set_parent_shot
        @shot = Shot.find(params[:shot_id])
      end

      # Now find the specific join-record, but scoped to @shot
      def set_shot_asset
        @shot_asset = @shot.shot_assets.find(params[:id])
      end

      def shot_asset_params
        # Only allow the child foreign key; shot_id itself is implied by @shot
        params.require(:shot_asset).permit(:asset_id)
      end
    end
  end
end
