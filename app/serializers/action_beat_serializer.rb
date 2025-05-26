class ActionBeatSerializer < ActiveModel::Serializer
  attributes :id, :beat_type, :text, :description, :number, :dialogue, :notes, :created_at

  belongs_to :scene
  has_many :shots
end
