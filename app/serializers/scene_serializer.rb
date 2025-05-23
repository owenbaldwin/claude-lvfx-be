class SceneSerializer < ActiveModel::Serializer
  attributes :id,
             :number,
             :name,
             :description,
             :int_ext,
             :location,
             :day_night,
             :length,
             :created_at

  belongs_to :sequence
  has_many :action_beats
end
