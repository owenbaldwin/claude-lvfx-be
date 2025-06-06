class ShotSerializer < ActiveModel::Serializer
  attributes :id,
             :number,
             :description,
             :camera_angle,
             :camera_movement,
             :status,
             :notes,
             :created_at,
             :version_number,
             :source_shot_id,
             :is_active,
             :production_id,
             :script_id,
             :action_beat_id,
             :scene_id,
             :sequence_id,
             :color

  # Conditional attributes only included when available from joins
  attribute :sequence_prefix, if: -> { object.respond_to?(:sequence_prefix) }
  attribute :scene_number, if: -> { object.respond_to?(:scene_number) }
  attribute :action_beat_number, if: -> { object.respond_to?(:action_beat_number) }

  belongs_to :action_beat
end
