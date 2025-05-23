module Api
  module V1
    class SequencesController < ApplicationController
      before_action :set_production
      before_action :set_sequence, only: [:show, :update, :destroy]

      # GET /api/v1/productions/{production_id}/sequences
      def index
        @sequences = @production.sequences.order(:number)
        render json: @sequences.as_json(only: [:id, :number, :prefix, :name, :description, :script_id, :production_id]), status: :ok
      end

      # GET /api/v1/productions/{production_id}/sequences/{id}
      def show
        render json: @sequence.as_json(only: [:id, :number, :prefix, :name, :description, :script_id, :production_id]), status: :ok
      end

      # POST /api/v1/productions/{production_id}/sequences
      def create
        Rails.logger.info("Raw Parameters: #{params.inspect}")

        insert_position = params[:position].to_i
        if insert_position.nil? || insert_position <= 0
          insert_position = (@production.sequences.maximum(:number) || 0) + 1
        end

        ActiveRecord::Base.transaction do
          if @production.sequences.exists?(number: insert_position)
            @production.sequences
                      .where("number >= ?", insert_position)
                      .order(number: :desc)
                      .each { |seq| seq.update_column(:number, seq.number + 1) }
          end


          @sequence = @production.sequences.new(sequence_params.merge(number: insert_position, production_id: @production.id))


          if @sequence.save
            render json: @sequence, status: :created
          else
            Rails.logger.error "Sequence creation failed: #{@sequence.errors.full_messages}"
            raise ActiveRecord::Rollback
          end
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
