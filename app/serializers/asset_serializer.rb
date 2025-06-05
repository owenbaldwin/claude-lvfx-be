class AssetSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :complexity_id, :production_id, :created_at, :updated_at

  belongs_to :complexity
  has_many :shot_assets
  has_many :shots, through: :shot_assets
end
