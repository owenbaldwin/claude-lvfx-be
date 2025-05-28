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

  belongs_to :action_beat
end
