class ShotAssetSerializer < ActiveModel::Serializer
  attributes :id, :shot_id, :asset_id, :created_at, :updated_at

  belongs_to :shot
  belongs_to :asset
end
