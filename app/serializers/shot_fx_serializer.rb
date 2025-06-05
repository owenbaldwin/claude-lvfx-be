class ShotFxSerializer < ActiveModel::Serializer
  attributes :id, :shot_id, :fx_id, :created_at, :updated_at

  belongs_to :shot
  belongs_to :fx
end
