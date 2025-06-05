module Api
  module V1
    class CharactersController < ApplicationController
      before_action :set_production
      before_action :set_character, only: [:show, :update, :destroy]
      before_action :set_scene, only: [:scene_characters]
      before_action :set_action_beat, only: [:action_beat_characters]

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

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/characters
      def scene_characters
        @characters = Character.joins(:character_appearances)
                               .where(character_appearances: { scene_id: @scene.id })
                               .where(production_id: @production.id)
                               .distinct
                               .order(:full_name)
        render json: @characters, status: :ok
      end

      # GET /api/v1/productions/:production_id/sequences/:sequence_id/scenes/:scene_id/action_beats/:action_beat_id/characters
      def action_beat_characters
        @characters = Character.joins(:character_appearances)
                               .where(character_appearances: { action_beat_id: @action_beat.id })
                               .where(production_id: @production.id)
                               .distinct
                               .order(:full_name)
        render json: @characters, status: :ok
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_character
        @character = @production.characters.find(params[:id])
      end

      def set_scene
        @sequence = @production.sequences.find(params[:sequence_id])
        @scene = @sequence.scenes.find(params[:scene_id])
      end

      def set_action_beat
        @sequence = @production.sequences.find(params[:sequence_id])
        @scene = @sequence.scenes.find(params[:scene_id])
        @action_beat = @scene.action_beats.find(params[:action_beat_id])
      end

      def character_params
        params.require(:character).permit(:full_name, :description, :actor)
      end
    end
  end
end
