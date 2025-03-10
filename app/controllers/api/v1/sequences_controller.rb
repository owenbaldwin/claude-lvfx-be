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
        @script = @production.scripts.first # Default to first script or handle as needed
        
        @sequence = @production.sequences.new(sequence_params)
        @sequence.script = @script
        
        if @sequence.save
          render json: @sequence, status: :created
        else
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
        params.permit(:number, :prefix, :name, :description, :script_id)
      end
    end
  end
end