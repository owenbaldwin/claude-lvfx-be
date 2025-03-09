class ActionBeatSerializer < ActiveModel::Serializer
  attributes :id, :description, :order_number, :dialogue, :notes, :created_at
  
  belongs_to :scene
  has_many :shots
end