class Asset < ApplicationRecord
  belongs_to :complexity
  belongs_to :production

  has_many :shot_assets, dependent: :destroy
  has_many :shots, through: :shot_assets

  validates :name,        presence: true
  validates :description, presence: true
end
