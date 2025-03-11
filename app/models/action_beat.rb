class ActionBeat < ApplicationRecord
  belongs_to :scene
  belongs_to :sequence
  belongs_to :script, optional: true
  belongs_to :production
  has_many :shots, dependent: :destroy
  
  validates :number, presence: true, numericality: { only_integer: true }
  validates :text, presence: true
  validates :beat_type, inclusion: { in: ['dialogue', 'action'] }
  
  # Ensure uniqueness of number within a scene
  validates :number, uniqueness: { scope: :scene_id, message: "must be unique within a scene" }
end