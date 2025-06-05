module Api
  module V1
    class AssetsController < ApplicationController
      before_action :set_production
      before_action :set_asset, only: [:show, :update, :destroy]
      before_action :set_shot, only: [:shot_assets]

      # GET /api/v1/productions/:production_id/assets
      def index
        @assets = @production.assets
        render json: @assets
      end

      # GET /api/v1/productions/:production_id/assets/:id
      def show
        render json: @asset
      end

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/shots/:shot_id/assets
      def shot_assets
        @assets = Asset.joins(:shot_assets)
                      .where(shot_assets: { shot_id: @shot.id })
                      .where(production_id: @production.id)
                      .distinct
                      .order(:name)
        render json: @assets, status: :ok
      end

      # POST /api/v1/productions/:production_id/assets
      def create
        production = @current_user.productions.find(params[:production_id])

        @asset = Asset.new(asset_params)
        @asset.production = production

        if @asset.save
          render json: @asset, status: :created
        else
          render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/assets/:id
      def update
        if @asset.update(asset_params)
          render json: @asset
        else
          render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/assets/:id
      def destroy
        @asset.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_asset
        @asset = @production.assets.find(params[:id])
      end

      def set_shot
        @shot = Shot.find(params[:shot_id])
      end

      def asset_params
        params.require(:asset).permit(:name, :description, :complexity_id)
      end
    end
  end
end
