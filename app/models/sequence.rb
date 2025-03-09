class Sequence < ApplicationRecord
  belongs_to :script
  has_many :scenes, dependent: :destroy
  
  validates :number, presence: true
end