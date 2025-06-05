module Api
  module V1
    class FxController < ApplicationController
      before_action :set_fx, only: [:show, :update, :destroy]

      # GET /api/v1/fx
      def index
        @fxs = Fx.all
        render json: @fxs
      end

      # GET /api/v1/fx/:id
      def show
        render json: @fx
      end

      # POST /api/v1/fx
      def create
        @fx = Fx.new(fx_params)

        if @fx.save
          render json: @fx, status: :created
        else
          render json: { errors: @fx.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/fx/:id
      def update
        if @fx.update(fx_params)
          render json: @fx
        else
          render json: { errors: @fx.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/fx/:id
      def destroy
        @fx.destroy
        head :no_content
      end

      private

      def set_fx
        @fx = Fx.find(params[:id])
      end

      def fx_params
        params.require(:fx).permit(:name, :description, :complexity_id, :production_id)
      end
    end
  end
end
