module Api
  module V1
    class CharacterAppearancesController < ApplicationController
      before_action :set_production
      before_action :set_character_appearance, only: [:show, :update, :destroy]

      # GET /api/v1/productions/:production_id/character_appearances
      def index
        @appearances = @production.character_appearances
                                   .includes(:character, :scene, :action_beat)
                                   .order(:created_at)
        render json: @appearances, status: :ok
      end

      # GET /api/v1/productions/:production_id/character_appearances/:id
      def show
        render json: @appearance, status: :ok
      end

      # POST /api/v1/productions/:production_id/character_appearances
      def create
        @appearance = @production.character_appearances.new(appearance_params)
        if @appearance.save
          render json: @appearance, status: :created
        else
          render json: { errors: @appearance.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/productions/:production_id/character_appearances/:id
      def update
        if @appearance.update(appearance_params)
          render json: @appearance, status: :ok
        else
          render json: { errors: @appearance.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/productions/:production_id/character_appearances/:id
      def destroy
        @appearance.destroy
        head :no_content
      end

      # POST /api/v1/productions/:production_id/character_appearances/for_action_beat
      def for_action_beat
        @character = @production.characters.find(params[:character_id])
        @action_beat = ActionBeat.joins(scene: { sequence: :production })
                                 .where(productions: { id: @production.id })
                                 .find(params[:action_beat_id])

        @appearance = CharacterAppearance.new(
          character: @character,
          action_beat: @action_beat
        )

        if @appearance.save
          render json: @appearance, status: :created
        else
          render json: { errors: @appearance.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: "Character or Action Beat not found" }, status: :not_found
      end

      # POST /api/v1/productions/:production_id/character_appearances/for_scene
      def for_scene
        @character = @production.characters.find(params[:character_id])
        @scene = Scene.joins(sequence: :production)
                      .where(productions: { id: @production.id })
                      .find(params[:scene_id])

        @appearance = CharacterAppearance.new(
          character: @character,
          scene: @scene
        )

        if @appearance.save
          render json: @appearance, status: :created
        else
          render json: { errors: @appearance.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound => e
        render json: { error: "Character or Scene not found" }, status: :not_found
      end

      private

      def set_production
        @production = @current_user.productions.find(params[:production_id])
      end

      def set_character_appearance
        @appearance = @production.character_appearances.find(params[:id])
      end

      def appearance_params
        params.require(:character_appearance)
              .permit(:character_id, :scene_id, :action_beat_id, :shot_id)
      end
    end
  end
end
