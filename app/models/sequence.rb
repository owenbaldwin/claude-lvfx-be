class Sequence < ApplicationRecord
  belongs_to :script
  belongs_to :production
  has_many :scenes, dependent: :destroy
  has_many :action_beats, through: :scenes
  has_many :shots, through: :action_beats
  
  validates :number, presence: true, numericality: { only_integer: true }
  validates :name, presence: true
  
  # Ensure uniqueness of number within a script
  validates :number, uniqueness: { scope: :script_id, message: "must be unique within a script" }
end