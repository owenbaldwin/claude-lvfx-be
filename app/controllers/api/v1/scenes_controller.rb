module Api
  module V1
    class ScenesController < ApplicationController
      before_action :set_sequence
      before_action :set_scene, only: [:show, :update, :destroy]

      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes
      def index
        # @scenes = @sequence.scenes
        if params[:all_versions].present? && params[:scene_number].present?
          # Return *all* versions of a single scene (for the dropdown)
          @scenes = @sequence.scenes
                            .where(number: params[:scene_number])
                            .order(:version_number)
        elsif params[:script_id].present?
          # Script-driven mode
          @scenes = @sequence.scenes
                            .where(script_id: params[:script_id])
                            .order(:number, :version_number)
        else
          # Manual-entry / latest-only mode
          # @scenes = @sequence.scenes
          #                   .select('DISTINCT ON(scenes.number) scenes.*')
          #                   .order('scenes.number ASC, scenes.version_number DESC')
          @scenes = @sequence.scenes
                      .where(is_active: true)
                      .order(:number)
        end

        render json: @scenes, status: :ok, each_serializer: SceneSerializer
        # render json: @scenes, status: :ok
      end

      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{id}
      def show
        render json: @scene, status: :ok
      end

      # POST /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes
      def create
        @scene = @sequence.scenes.new(scene_params)
        @scene.script = @sequence.script
        @scene.production = @production

        if @scene.save
          render json: @scene, status: :created
        else
          render json: { errors: @scene.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{id}
      def update
        if @scene.update(scene_params)
          render json: @scene, status: :ok
        else
          render json: { errors: @scene.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{id}
      def destroy
        @scene.destroy
        head :no_content
      end

      private

      def set_sequence
        @production = @current_user.productions.find(params[:production_id])
        @sequence = @production.sequences.find(params[:sequence_id])
      end

      def set_scene
        @scene = @sequence.scenes.find(params[:id])
      end

      def scene_params
        # params.permit(:number, :int_ext, :location, :day_night, :length, :description, :script_id)
        params.permit(:number, :int_ext, :location, :day_night, :length, :description, :script_id, :is_active, :version_number,)
      end
    end
  end
end
