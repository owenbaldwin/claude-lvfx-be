module Api
  module V1
    class AssetsController < ApplicationController
      before_action :set_asset, only: [:show, :update, :destroy]

      # GET /api/v1/assets
      def index
        @assets = Asset.all
        render json: @assets
      end

      # GET /api/v1/assets/:id
      def show
        render json: @asset
      end

      # POST /api/v1/assets
      def create
        @asset = Asset.new(asset_params)

        if @asset.save
          render json: @asset, status: :created
        else
          render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/assets/:id
      def update
        if @asset.update(asset_params)
          render json: @asset
        else
          render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/assets/:id
      def destroy
        @asset.destroy
        head :no_content
      end

      private

      def set_asset
        @asset = Asset.find(params[:id])
      end

      def asset_params
        params.require(:asset).permit(:name, :description, :complexity_id, :production_id)
      end
    end
  end
end
