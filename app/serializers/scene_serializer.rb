class SceneSerializer < ActiveModel::Serializer
  attributes :id, :number, :name, :description, :setting, :time_of_day, :created_at
  
  belongs_to :sequence
  has_many :action_beats
end