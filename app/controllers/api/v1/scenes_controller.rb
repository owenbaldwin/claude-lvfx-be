module Api
  module V1
    class ScenesController < ApplicationController
      before_action :set_sequence
      before_action :set_scene, only: [:show, :update, :destroy]
      
      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes
      def index
        @scenes = @sequence.scenes
        render json: @scenes, status: :ok
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
        params.permit(:number, :int_ext, :location, :day_night, :length, :description, :script_id)
      end
    end
  end
end