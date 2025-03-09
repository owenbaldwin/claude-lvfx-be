class SequenceSerializer < ActiveModel::Serializer
  attributes :id, :number, :name, :description, :created_at
  
  belongs_to :script
  has_many :scenes
end