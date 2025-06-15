class Asset < ApplicationRecord
  belongs_to :complexity
  belongs_to :production

  has_many :shot_assets, dependent: :destroy
  has_many :shots, through: :shot_assets
  has_many :cost_estimates, dependent: :destroy

  validates :name,        presence: true
  validates :description, presence: true

  after_create :create_cost_estimate

  private

  def create_cost_estimate
    cost_estimates.create!(asset_id: id, production_id: production_id)
  end
end
