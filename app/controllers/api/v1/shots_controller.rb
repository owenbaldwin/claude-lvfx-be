module Api
  module V1
    class ShotsController < ApplicationController
      before_action :set_action_beat, except: [:production_shots]
      before_action :set_shot, only: [:show, :update, :destroy]
      before_action :set_production_for_production_shots, only: [:production_shots]

      # GET /api/v1/productions/{production_id}/shots
      def production_shots
        @shots = @production.shots
                            .joins(action_beat: { scene: :sequence })
                            .select('shots.*,
                                     action_beats.number as action_beat_number,
                                     scenes.number as scene_number,
                                     sequences.prefix as sequence_prefix')
                            .order(:number, :version_number)

        render json: @shots, status: :ok, each_serializer: ShotSerializer
      end

      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{action_beat_id}/shots
      def index
        # @shots = @action_beat.shots
        if params[:script_id].present?
          @shots = @action_beat.shots
                              .where(script_id: params[:script_id])
                              .order(:number, :version_number)
        else
          @shots = @action_beat.shots
                              .select('DISTINCT ON(shots.number) shots.*')
                              .order('shots.number ASC, shots.version_number DESC')
        end

        render json: @shots, status: :ok, each_serializer: ShotSerializer
        # render json: @shots, status: :ok
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

      def set_production_for_production_shots
        @production = @current_user.productions.find(params[:production_id])
      end

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
        # params.permit(:number, :description, :vfx, :duration, :camera_angle, :camera_movement, :status, :notes, :script_id)
        params.permit(:number, :description, :vfx, :duration, :camera_angle,:camera_movement, :status, :notes, :script_id, :is_active)
      end
    end
  end

end
