class Scene < ApplicationRecord
  belongs_to :sequence
  has_many :action_beats, dependent: :destroy
  
  validates :number, presence: true
end