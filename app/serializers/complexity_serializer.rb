class ComplexitySerializer < ActiveModel::Serializer
  attributes :id, :key, :level, :description, :production_id, :user_id, :created_at, :updated_at

  has_many :assumptions
  has_many :assets
  has_many :fxs
end
