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
             :is_active

  belongs_to :action_beat
end
