class ActionBeatSerializer < ActiveModel::Serializer
  attributes :id,
             :beat_type,
             :text,
             :description,
             :number,
             :dialogue,
             :notes,
             :created_at,
             :version_number,
             :is_active,
             :source_beat_id,
             :production_id,
             :script_id,
             :scene_id,
             :sequence_id,
             :color

  belongs_to :scene
  has_many :shots
end
