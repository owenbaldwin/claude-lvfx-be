module Api
  module V1
    class ShotAssumptionsController < ApplicationController
      before_action :set_shot_assumption, only: [:show, :update, :destroy]

      # GET /api/v1/shot_assumptions
      def index
        @shot_assumptions = ShotAssumption.all
        render json: @shot_assumptions
      end

      # GET /api/v1/shot_assumptions/:id
      def show
        render json: @shot_assumption
      end

      # POST /api/v1/shot_assumptions
      def create
        @shot_assumption = ShotAssumption.new(shot_assumption_params)

        if @shot_assumption.save
          render json: @shot_assumption, status: :created
        else
          render json: { errors: @shot_assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/shot_assumptions/:id
      def update
        if @shot_assumption.update(shot_assumption_params)
          render json: @shot_assumption
        else
          render json: { errors: @shot_assumption.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/shot_assumptions/:id
      def destroy
        @shot_assumption.destroy
        head :no_content
      end

      private

      def set_shot_assumption
        @shot_assumption = ShotAssumption.find(params[:id])
      end

      def shot_assumption_params
        params.require(:shot_assumption).permit(:shot_id, :assumption_id)
      end
    end
  end
end
