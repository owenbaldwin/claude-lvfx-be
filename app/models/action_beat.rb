class ActionBeat < ApplicationRecord
  belongs_to :scene
  belongs_to :sequence
  belongs_to :script
  belongs_to :production
  has_many :shots, dependent: :destroy
  
  validates :number, presence: true, numericality: { only_integer: true }
  validates :text, presence: true
  validates :type, inclusion: { in: ['dialogue', 'action'] }
  
  # Ensure uniqueness of number within a scene
  validates :number, uniqueness: { scope: :scene_id, message: "must be unique within a scene" }
end