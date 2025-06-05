class ShotAsset < ApplicationRecord
  belongs_to :shot
  belongs_to :asset

  validates :shot_id,  presence: true
  validates :asset_id, presence: true
end
