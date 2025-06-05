class Complexity < ApplicationRecord
  belongs_to :production
  belongs_to :user

  has_many :assumptions, dependent: :destroy
  has_many :assets,      dependent: :destroy
  has_many :fxs,         class_name: "Fx", dependent: :destroy

  validates :level, presence: true
  validates :description, presence: true
end
