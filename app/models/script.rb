class Script < ApplicationRecord
  belongs_to :production
  has_many :sequences, dependent: :destroy
  has_many :scenes, through: :sequences
  has_many :action_beats, through: :scenes
  has_many :shots, through: :action_beats
  
  validates :title, presence: true
end