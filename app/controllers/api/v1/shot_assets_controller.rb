module Api
  module V1
    class ShotAssetsController < ApplicationController
      before_action :set_shot_asset, only: [:show, :update, :destroy]

      # GET /api/v1/shot_assets
      def index
        @shot_assets = ShotAsset.all
        render json: @shot_assets
      end

      # GET /api/v1/shot_assets/:id
      def show
        render json: @shot_asset
      end

      # POST /api/v1/shot_assets
      def create
        @shot_asset = ShotAsset.new(shot_asset_params)

        if @shot_asset.save
          render json: @shot_asset, status: :created
        else
          render json: { errors: @shot_asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/shot_assets/:id
      def update
        if @shot_asset.update(shot_asset_params)
          render json: @shot_asset
        else
          render json: { errors: @shot_asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/shot_assets/:id
      def destroy
        @shot_asset.destroy
        head :no_content
      end

      private

      def set_shot_asset
        @shot_asset = ShotAsset.find(params[:id])
      end

      def shot_asset_params
        params.require(:shot_asset).permit(:shot_id, :asset_id)
      end
    end
  end
end
