class SceneSerializer < ActiveModel::Serializer
  attributes :id,
             :number,
             :name,
             :description,
             :int_ext,
             :location,
             :day_night,
             :length,
             :created_at,
             :version_number,
             :is_active,
             :source_scene_id,
             :production_id,
             :script_id,
             :sequence_id,
             :color

  belongs_to :sequence
  has_many :action_beats
end
