module Api
  module V1
    class SequencesController < ApplicationController
      before_action :set_script
      before_action :set_sequence, only: [:show, :update, :destroy]
      
      # GET /api/v1/productions/{production_id}/scripts/{script_id}/sequences
      def index
        @sequences = @script.sequences
        render json: @sequences, status: :ok
      end
      
      # GET /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{id}
      def show
        render json: @sequence, status: :ok
      end
      
      # POST /api/v1/productions/{production_id}/scripts/{script_id}/sequences
      def create
        @sequence = @script.sequences.new(sequence_params)
        
        if @sequence.save
          render json: @sequence, status: :created
        else
          render json: { errors: @sequence.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PUT /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{id}
      def update
        if @sequence.update(sequence_params)
          render json: @sequence, status: :ok
        else
          render json: { errors: @sequence.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/productions/{production_id}/scripts/{script_id}/sequences/{id}
      def destroy
        @sequence.destroy
        head :no_content
      end
      
      private
      
      def set_script
        @production = @current_user.productions.find(params[:production_id])
        @script = @production.scripts.find(params[:script_id])
      end
      
      def set_sequence
        @sequence = @script.sequences.find(params[:id])
      end
      
      def sequence_params
        params.permit(:number, :name, :description)
      end
    end
  end
end