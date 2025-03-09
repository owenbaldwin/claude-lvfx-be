class ScriptSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :version, :date, :created_at
  
  belongs_to :production
  has_many :sequences
end