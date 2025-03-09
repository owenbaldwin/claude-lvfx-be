class ActionBeat < ApplicationRecord
  belongs_to :scene
  has_many :shots, dependent: :destroy

  validates :description, presence: true

end
