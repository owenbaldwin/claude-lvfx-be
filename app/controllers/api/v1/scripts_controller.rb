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
        script = @production.scripts.find(params[:id])

        # Create ScriptParse record to track the job
        script_parse = @production.script_parses.create!(
          job_id: SecureRandom.uuid,
          script: script,
          status: 'pending'
        )

        # enqueue the parsing job with the script_parse ID
        ParseScriptJob.perform_later(params[:production_id], script.id, script_parse.id)

        # Return job information
        render json: {
          job_id: script_parse.job_id,
          status: script_parse.status,
          message: 'Script parsing job has been queued'
        }, status: :accepted
      end

      # GET /api/v1/productions/:production_id/scripts/:id/parse/:job_id/status
      def parse_status
        script = @production.scripts.find(params[:id])
        script_parse = script.script_parses.find_by!(job_id: params[:job_id])

        render json: {
          job_id: script_parse.job_id,
          status: script_parse.status,
          error: script_parse.error,
          created_at: script_parse.created_at,
          updated_at: script_parse.updated_at
        }
      end

      # GET /api/v1/productions/:production_id/scripts/:id/parse/:job_id/results
      def parse_results
        script = @production.scripts.find(params[:id])
        script_parse = script.script_parses.find_by!(job_id: params[:job_id])

        unless script_parse.completed?
          render json: {
            job_id: script_parse.job_id,
            status: script_parse.status,
            error: script_parse.error || 'Results not available - job has not completed successfully'
          }, status: :accepted
          return
        end

        render json: {
          job_id: script_parse.job_id,
          status: script_parse.status,
          results: script_parse.results_json,
          created_at: script_parse.created_at,
          completed_at: script_parse.updated_at
        }
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
