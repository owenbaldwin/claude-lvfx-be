module Api
  module V1
    class CharactersController < ApplicationController
      before_action :set_production
      before_action :set_character, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/characters
      def index
        @characters = @production.characters.order(:full_name)
        render json: @characters, status: :ok
      end

      # GET /api/v1/productions/:production_id/characters/:id
      def show
        render json: @character, status: :ok
      end

      # POST /api/v1/productions/:production_id/characters
      def create
        @character = @production.characters.new(character_params)
        if @character.save
          render json: @character, status: :created
        else
          render json: { errors: @character.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/productions/:production_id/characters/:id
      def update
        if @character.update(character_params)
          render json: @character, status: :ok
        else
          render json: { errors: @character.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/characters/:id
      def destroy
        @character.destroy
        head :no_content
      end

      private

      def set_production
        @production = current_user.productions.find(params[:production_id])
      end

      def set_character
        @character = @production.characters.find(params[:id])
      end

      def character_params
        params.require(:character).permit(:full_name, :description, :actor)
      end
    end
  end
end
