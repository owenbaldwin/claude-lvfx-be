class ShotAssumptionSerializer < ActiveModel::Serializer
  attributes :id, :shot_id, :assumption_id, :created_at, :updated_at

  belongs_to :shot
  belongs_to :assumption
end
