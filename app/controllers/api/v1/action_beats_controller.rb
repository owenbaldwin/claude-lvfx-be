module Api
  module V1
    class ActionBeatsController < ApplicationController
      before_action :set_scene, except: [:update_unsequenced, :generate_shots, :job_status, :job_results]
      before_action :set_action_beat, only: [:show, :update, :destroy]
      before_action :set_production_and_scene_for_unsequenced, only: [:update_unsequenced]
      before_action :set_unsequenced_action_beat, only: [:update_unsequenced]

      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats
      def index
        # @action_beats = @scene.action_beats
        if params[:all_versions].present? && params[:beat_number].present?
          # Return *all* versions of a single action beat (for the dropdown)
          @action_beats = @scene.action_beats
                                .where(number: params[:beat_number])
                                .order(:version_number)
        elsif params[:script_id].present?
          # Script-driven mode
          @action_beats = @scene.action_beats
                                .where(script_id: params[:script_id])
                                .order(:number, :version_number)
        else
          # Manual-entry / latest-only mode
          # @action_beats = @scene.action_beats
          #                       .select('DISTINCT ON(action_beats.number) action_beats.*')
          #                       .order('action_beats.number ASC, action_beats.version_number DESC')
          @action_beats = @scene.action_beats
                                .where(is_active: true)
                                .order(:number)
        end

        render json: @action_beats, status: :ok, each_serializer: ActionBeatSerializer
        # render json: @action_beats, status: :ok
      end

      # GET /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{id}
      def show
        render json: @action_beat, status: :ok
      end

      # POST /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats
      def create
        @action_beat = @scene.action_beats.new(action_beat_params)
        @action_beat.script = @scene.script
        @action_beat.production = @production
        @action_beat.sequence = @sequence

        if @action_beat.save
          render json: @action_beat, status: :created
        else
          render json: { errors: @action_beat.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{id}
      def update
        if @action_beat.update(action_beat_params)
          render json: @action_beat, status: :ok
        else
          render json: { errors: @action_beat.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/productions/{production_id}/scenes/{scene_id}/action_beats/{id}/update_unsequenced
      def update_unsequenced
        Rails.logger.debug "Received params: #{params.inspect}"
        Rails.logger.debug "Action beat params: #{action_beat_params.inspect}"
        Rails.logger.debug "Action beat before update: scene_id=#{@action_beat.scene_id}, id=#{@action_beat.id}"

        if @action_beat.update(action_beat_params)
          Rails.logger.debug "Action beat after update: scene_id=#{@action_beat.scene_id}, id=#{@action_beat.id}"
          render json: @action_beat, status: :ok
        else
          Rails.logger.debug "Update failed: #{@action_beat.errors.full_messages}"
          render json: { errors: @action_beat.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/{production_id}/sequences/{sequence_id}/scenes/{scene_id}/action_beats/{id}
      def destroy
        @action_beat.destroy
        head :no_content
      end

      # POST /api/v1/productions/:production_id/action_beats/generate_shots
      def generate_shots
        # Get production and validate user access
        @production = @current_user.productions.find(params[:production_id])

        # Validate required parameters
        unless params[:action_beat_ids].present?
          render json: { error: 'action_beat_ids parameter is required' }, status: :bad_request
          return
        end

        # Validate that action_beat_ids is an array of integers
        action_beat_ids = params[:action_beat_ids]
        unless action_beat_ids.is_a?(Array) && action_beat_ids.all? { |id| id.is_a?(Integer) || id.to_s.match?(/\A\d+\z/) }
          render json: { error: 'action_beat_ids must be an array of integers' }, status: :bad_request
          return
        end

        # Convert to integers
        action_beat_ids = action_beat_ids.map(&:to_i)

        # Validate that all action beats belong to this production
        action_beats = ActionBeat.where(id: action_beat_ids, production_id: @production.id)
        if action_beats.count != action_beat_ids.count
          invalid_ids = action_beat_ids - action_beats.pluck(:id)
          render json: { error: "Action beats with IDs #{invalid_ids.join(', ')} do not belong to this production or do not exist" }, status: :bad_request
          return
        end

        # Create ShotGeneration record to track the job
        shot_generation = @production.shot_generations.create!(
          job_id: SecureRandom.uuid,
          status: 'pending'
        )

        # Queue the background job with the shot_generation ID
        GenerateShotsJob.perform_later(@current_user.id, action_beat_ids, shot_generation.id)

        # Return 202 Accepted with job information
        render json: {
          job_id: shot_generation.job_id,
          status: shot_generation.status,
          message: 'Shot generation job has been queued'
        }, status: :accepted
      end

      # GET /api/v1/productions/:production_id/action_beats/job/:job_id/status
      def job_status
        @production = @current_user.productions.find(params[:production_id])
        shot_generation = @production.shot_generations.find_by!(job_id: params[:job_id])

        render json: {
          job_id: shot_generation.job_id,
          status: shot_generation.status,
          error: shot_generation.error,
          created_at: shot_generation.created_at,
          updated_at: shot_generation.updated_at
        }
      end

      # GET /api/v1/productions/:production_id/action_beats/job/:job_id/results
      def job_results
        @production = @current_user.productions.find(params[:production_id])
        shot_generation = @production.shot_generations.find_by!(job_id: params[:job_id])

        unless shot_generation.completed?
          render json: {
            job_id: shot_generation.job_id,
            status: shot_generation.status,
            error: shot_generation.error || 'Results not available - job has not completed successfully'
          }, status: :accepted
          return
        end

        render json: {
          job_id: shot_generation.job_id,
          status: shot_generation.status,
          results: shot_generation.results_json,
          created_at: shot_generation.created_at,
          completed_at: shot_generation.updated_at
        }
      end

      private

      def set_scene
        @production = @current_user.productions.find(params[:production_id])
        @sequence = @production.sequences.find(params[:sequence_id])
        @scene = @sequence.scenes.find(params[:scene_id])
      end

      def set_production_and_scene_for_unsequenced
        @production = @current_user.productions.find(params[:production_id])
        @scene = @production.scenes.find(params[:scene_id])
      end

      def set_action_beat
        @action_beat = @scene.action_beats.find(params[:id])
      end

      def set_unsequenced_action_beat
        @action_beat = @scene.action_beats.find(params[:id])
      end

      def action_beat_params
        # params.permit(:number, :beat_type, :text, :description, :dialogue, :notes, :script_id)
        permitted_params = params.permit(:number, :beat_type, :text, :description, :dialogue, :notes, :script_id, :is_active, :version_number, :source_beat_id, :color, :scene_id, :production_id, :sequence_id)

        # Handle camelCase conversion for update_unsequenced
        if action_name == 'update_unsequenced'
          permitted_params[:scene_id] = params[:sceneId] if params[:sceneId].present?
          permitted_params[:sequence_id] = params[:sequenceId] if params[:sequenceId].present?
        end

        permitted_params
      end
    end
  end
end
