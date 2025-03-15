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
        # Log the raw parameters for debugging
        Rails.logger.info("Raw Parameters: #{params.inspect}")
        
        # Check if script_id was provided in the params, otherwise use the first script if available
        script_id = params[:script_id] || (params[:sequence] && params[:sequence][:script_id])
        
        if script_id.present?
          @script = @production.scripts.find_by(id: script_id)
        else
          @script = @production.scripts.first
        end
        
        # Create the new sequence with the production association
        @sequence = @production.sequences.new
        
        # Manually set attributes from params instead of using strong parameters
        # to handle both nested and non-nested formats
        if params[:sequence].present?
          # Nested params format
          @sequence.name = params[:sequence][:name]
          @sequence.number = params[:sequence][:number]
          @sequence.prefix = params[:sequence][:prefix]
          @sequence.description = params[:sequence][:description]
        else
          # Non-nested params format
          @sequence.name = params[:name]
          @sequence.number = params[:number]
          @sequence.prefix = params[:prefix]
          @sequence.description = params[:description]
        end
        
        # Set default values if not provided
        @sequence.name ||= "New Sequence"
        @sequence.number ||= next_available_sequence_number
        
        # Set the script if available
        @sequence.script = @script if @script.present?
        
        # Log parameters to help with debugging
        Rails.logger.info("Creating sequence with attributes: #{@sequence.attributes.inspect}")
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
        if params[:sequence].present?
          update_params = sequence_params
        else
          update_params = params.permit(:number, :prefix, :name, :description, :script_id)
        end
        
        if @sequence.update(update_params)
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
        params.require(:sequence).permit(:number, :prefix, :name, :description, :script_id)
      end
      
      def next_available_sequence_number
        # Find the highest existing sequence number and add 1
        highest = @production.sequences.maximum(:number) || 0
        highest + 1
      end
    end
  end
end