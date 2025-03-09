class Script < ApplicationRecord
  belongs_to :production
  has_many :sequences, dependent: :destroy
  
  validates :title, presence: true
end