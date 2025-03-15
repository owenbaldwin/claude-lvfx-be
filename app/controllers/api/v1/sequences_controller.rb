module Api
  module V1
    class SequencesController < ApplicationController
      before_action :set_production
      before_action :set_sequence, only: [:show, :update, :destroy]
      
      # GET /api/v1/productions/{production_id}/sequences
      def index
        @sequences = @production.sequences
        render json: @sequences, status: :ok
      end
      
      # GET /api/v1/productions/{production_id}/sequences/{id}
      def show
        render json: @sequence, status: :ok
      end
      
      # POST /api/v1/productions/{production_id}/sequences
      def create
        # Check if script_id was provided in the params, otherwise use the first script if available
        if params[:script_id].present?
          @script = @production.scripts.find_by(id: params[:script_id])
        else
          @script = @production.scripts.first
        end
        
        # Create the new sequence with the production association
        @sequence = @production.sequences.new(sequence_params)
        
        # Set the script if available
        @sequence.script = @script if @script.present?
        
        # Log parameters to help with debugging
        Rails.logger.info("Creating sequence with params: #{sequence_params.inspect}")
        Rails.logger.info("Production: #{@production.inspect}")
        Rails.logger.info("Script: #{@script.inspect}")
        
        if @sequence.save
          render json: @sequence, status: :created
        else
          # Log validation errors for debugging
          Rails.logger.error("Sequence validation errors: #{@sequence.errors.full_messages}")
          render json: { errors: @sequence.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/productions/{production_id}/sequences/{id}
      def update
        if @sequence.update(sequence_params)
          render json: @sequence, status: :ok
        else
          render json: { errors: @sequence.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/productions/{production_id}/sequences/{id}
      def destroy
        @sequence.destroy
        head :no_content
      end
      
      private
      
      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end
      
      def set_sequence
        @sequence = @production.sequences.find(params[:id])
      end
      
      def sequence_params
        # Allow script_id to be passed as a parameter if needed
        params.require(:sequence).permit(:number, :prefix, :name, :description, :script_id)
      end
    end
  end
end