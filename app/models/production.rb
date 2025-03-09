class Production < ApplicationRecord
  has_many :production_users, dependent: :destroy
  has_many :users, through: :production_users
  has_many :scripts, dependent: :destroy
  
  validates :title, presence: true
end