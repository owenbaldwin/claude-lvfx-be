module Api
  module V1
    class ActionBeatsController < ApplicationController
      before_action :set_scene
      before_action :set_action_beat, only: [:show, :update, :destroy]
      
      # GET /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats
      def index
        @action_beats = @scene.action_beats
        render json: @action_beats, status: :ok
      end
      
      # GET /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{id}
      def show
        render json: @action_beat, status: :ok
      end
      
      # POST /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats
      def create
        @action_beat = @scene.action_beats.new(action_beat_params)
        @action_beat.script = @script
        @action_beat.production = @production
        @action_beat.sequence = @sequence
        
        if @action_beat.save
          render json: @action_beat, status: :created
        else
          render json: { errors: @action_beat.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{id}
      def update
        if @action_beat.update(action_beat_params)
          render json: @action_beat, status: :ok
        else
          render json: { errors: @action_beat.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{id}
      def destroy
        @action_beat.destroy
        head :no_content
      end
      
      private
      
      def set_scene
        @production = @current_user.productions.find(params[:production_id])
        @script = @production.scripts.find(params[:script_id])
        @sequence = @script.sequences.find(params[:sequence_id])
        @scene = @sequence.scenes.find(params[:scene_id])
      end
      
      def set_action_beat
        @action_beat = @scene.action_beats.find(params[:id])
      end
      
      def action_beat_params
        params.permit(:number, :type, :text, :description, :dialogue, :notes)
      end
    end
  end
end