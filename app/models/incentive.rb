class Incentive < ApplicationRecord
  belongs_to :production
  has_many :cost_estimates, dependent: :nullify

  validates :name, presence: true
  validates :percentage, presence: true, numericality: { greater_than: 0, less_than: 100 }
end
