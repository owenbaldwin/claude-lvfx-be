class ShotAssumption < ApplicationRecord
  belongs_to :shot
  belongs_to :assumption

  validates :shot_id, presence: true
  validates :assumption_id, presence: true
end
