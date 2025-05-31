module Api
  module V1
    class ScriptsController < ApplicationController
      before_action :set_production
      before_action :set_script, only: [:show, :update, :destroy]

      # GET /api/v1/productions/{production_id}/scripts
      def index
        @scripts = @production.scripts
        render json: @scripts, status: :ok
      end

      # GET /api/v1/productions/{production_id}/scripts/{id}
      def show
        render json: @script, status: :ok
      end

      # POST /api/v1/productions/{production_id}/scripts
      def create
        @script = @production.scripts.new(script_params)

        if @script.save
          render json: @script, status: :created
        else
          render json: { errors: @script.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/productions/:production_id/scripts/:id/parse
      def parse
        script = Script.find(params[:id])
        # enqueue the parsing job
        ParseScriptJob.perform_later(params[:production_id], script.id)
        render json: { status: 'queued' }, status: :accepted
      end

      # PUT /api/v1/productions/{production_id}/scripts/{id}
      def update
        if @script.update(script_params)
          render json: @script, status: :ok
        else
          render json: { errors: @script.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/{production_id}/scripts/{id}
      def destroy
        @script.destroy
        head :no_content
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_script
        @script = @production.scripts.find(params[:id])
      end

      def script_params
        # params.permit(:title, :description, :version, :date)
        params.permit(:title, :description, :version_number, :date, :color, :file)
      end
    end
  end
end
