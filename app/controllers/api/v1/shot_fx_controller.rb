module Api
  module V1
    class ShotFxController < ApplicationController
      before_action :set_shot_fx, only: [:show, :update, :destroy]

      # GET /api/v1/shot_fx
      def index
        @shot_fx = ShotFx.all
        render json: @shot_fx
      end

      # GET /api/v1/shot_fx/:id
      def show
        render json: @shot_fx
      end

      # POST /api/v1/shot_fx
      def create
        @shot_fx = ShotFx.new(shot_fx_params)

        if @shot_fx.save
          render json: @shot_fx, status: :created
        else
          render json: { errors: @shot_fx.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/shot_fx/:id
      def update
        if @shot_fx.update(shot_fx_params)
          render json: @shot_fx
        else
          render json: { errors: @shot_fx.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/shot_fx/:id
      def destroy
        @shot_fx.destroy
        head :no_content
      end

      private

      def set_shot_fx
        @shot_fx = ShotFx.find(params[:id])
      end

      def shot_fx_params
        params.require(:shot_fx).permit(:shot_id, :fx_id)
      end
    end
  end
end
