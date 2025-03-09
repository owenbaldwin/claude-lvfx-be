class ProductionSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :start_date, :end_date, :status, :created_at
  
  has_many :production_users
  has_many :scripts
end