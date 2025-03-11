class Scene < ApplicationRecord
  belongs_to :sequence
  belongs_to :script, optional: true
  belongs_to :production
  has_many :action_beats, dependent: :destroy
  has_many :shots, through: :action_beats
  
  validates :number, presence: true, numericality: { only_integer: true }
  validates :location, presence: true
  validates :int_ext, inclusion: { in: ['interior', 'exterior'] }
  validates :day_night, presence: true
  
  # Ensure uniqueness of number within a sequence
  validates :number, uniqueness: { scope: :sequence_id, message: "must be unique within a sequence" }
end