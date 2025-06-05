class Assumption < ApplicationRecord
  belongs_to :complexity
  belongs_to :production

  has_many :shot_assumptions, dependent: :destroy
  has_many :shots, through: :shot_assumptions

  validates :name, presence: true
  validates :description, presence: true
end
