class ProductionUserSerializer < ActiveModel::Serializer
  attributes :id, :role, :created_at
  
  belongs_to :user
  belongs_to :production
end