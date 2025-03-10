class Production < ApplicationRecord
  has_many :production_users, dependent: :destroy
  has_many :users, through: :production_users
  has_many :scripts, dependent: :destroy
  has_many :sequences, dependent: :destroy
  has_many :scenes, dependent: :destroy
  has_many :action_beats, dependent: :destroy
  has_many :shots, dependent: :destroy
  
  validates :title, presence: true
end