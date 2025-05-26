class Shot < ApplicationRecord
  belongs_to :action_beat
  belongs_to :scene
  belongs_to :sequence
  belongs_to :script, optional: true
  belongs_to :production

  validates :number, presence: true, numericality: { only_integer: true }
  validates :description, presence: true
  validates :vfx, inclusion: { in: ['yes', 'no'] }
  validates :camera_angle, presence: true, allow_blank: true
  validates :camera_movement, presence: true, allow_blank: true

  # Ensure uniqueness of number within an action beat
  validates :number, uniqueness: { scope: :action_beat_id, message: "must be unique within an action beat" }
end
