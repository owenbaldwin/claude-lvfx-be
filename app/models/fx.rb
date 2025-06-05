class Fx < ApplicationRecord
  # NOTE: model name "Fx" (plural is "fxs") to match your table name `fx`
  belongs_to :complexity
  belongs_to :production

  has_many :shot_fx, dependent: :destroy
  has_many :shots, through: :shot_fx

  validates :name,        presence: true
  validates :description, presence: true
end
