module Api
  module V1
    class ShotsController < ApplicationController
      before_action :set_action_beat
      before_action :set_shot, only: [:show, :update, :destroy]
      
      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{action_beat_id}/shots
      def index
        @shots = @action_beat.shots
        render json: @shots, status: :ok
      end
      
      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{action_beat_id}/shots/{id}
      def show
        render json: @shot, status: :ok
      end
      
      # POST /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{action_beat_id}/shots
      def create
        @shot = @action_beat.shots.new(shot_params)
        @shot.script = @action_beat.script
        @shot.production = @production
        @shot.scene = @scene
        @shot.sequence = @sequence
        
        if @shot.save
          render json: @shot, status: :created
        else
          render json: { errors: @shot.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{action_beat_id}/shots/{id}
      def update
        if @shot.update(shot_params)
          render json: @shot, status: :ok
        else
          render json: { errors: @shot.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{action_beat_id}/shots/{id}
      def destroy
        @shot.destroy
        head :no_content
      end
      
      private
      
      def set_action_beat
        @production = @current_user.productions.find(params[:production_id])
        @sequence = @production.sequences.find(params[:sequence_id])
        @scene = @sequence.scenes.find(params[:scene_id])
        @action_beat = @scene.action_beats.find(params[:action_beat_id])
      end
      
      def set_shot
        @shot = @action_beat.shots.find(params[:id])
      end
      
      def shot_params
        params.permit(:number, :description, :vfx, :duration, :camera_angle, :camera_movement, :status, :notes, :script_id)
      end
    end
  end
end