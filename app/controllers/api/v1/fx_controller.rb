module Api
  module V1
    class FxController < ApplicationController
      before_action :set_production
      before_action :set_fx, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/fx
      def index
        @fxs = @production.fxs
        render json: @fxs
      end

      # GET /api/v1/productions/:production_id/fx/:id
      def show
        render json: @fx
      end

      # POST /api/v1/productions/:production_id/fx
      def create
        production = @current_user.productions.find(params[:production_id])

        @fx = Fx.new(fx_params)
        @fx.production = production

        if @fx.save
          render json: @fx, status: :created
        else
          render json: { errors: @fx.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/productions/:production_id/fx/:id
      def update
        if @fx.update(fx_params)
          render json: @fx
        else
          render json: { errors: @fx.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/fx/:id
      def destroy
        @fx.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_fx
        @fx = @production.fxs.find(params[:id])
      end

      def fx_params
        params.require(:fx).permit(:name, :description, :complexity_id)
      end
    end
  end
end
