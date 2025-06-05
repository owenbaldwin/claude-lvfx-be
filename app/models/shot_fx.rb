class ShotFx < ApplicationRecord
  belongs_to :shot
  belongs_to :fx

  validates :shot_id, presence: true
  validates :fx_id,   presence: true
end
