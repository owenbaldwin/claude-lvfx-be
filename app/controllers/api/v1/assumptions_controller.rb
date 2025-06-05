module Api
  module V1
    class AssumptionsController < ApplicationController
      before_action :set_assumption, only: [:show, :update, :destroy]

      # GET /api/v1/assumptions
      def index
        @assumptions = Assumption.all
        render json: @assumptions
      end

      # GET /api/v1/assumptions/:id
      def show
        render json: @assumption
      end

      # POST /api/v1/assumptions
      def create
        @assumption = Assumption.new(assumption_params)

        if @assumption.save
          render json: @assumption, status: :created
        else
          render json: { errors: @assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/assumptions/:id
      def update
        if @assumption.update(assumption_params)
          render json: @assumption
        else
          render json: { errors: @assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/assumptions/:id
      def destroy
        @assumption.destroy
        head :no_content
      end

      private

      def set_assumption
        @assumption = Assumption.find(params[:id])
      end

      def assumption_params
        params.require(:assumption).permit(:name, :description, :complexity_id, :production_id)
      end
    end
  end
end
