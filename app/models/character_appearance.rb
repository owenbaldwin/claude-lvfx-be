# app/models/character_appearance.rb
class CharacterAppearance < ApplicationRecord
  belongs_to :character
  belongs_to :scene,       optional: true
  belongs_to :action_beat, optional: true
  belongs_to :shot,        optional: true

  validate :one_context_presence

  private

  # ensures exactly one of scene/action_beat/shot is set
  def one_context_presence
    present = [scene_id, action_beat_id, shot_id].count(&:present?)
    errors.add(:base, "Must assign exactly one of scene, action beat or shot") if present != 1
  end
end
