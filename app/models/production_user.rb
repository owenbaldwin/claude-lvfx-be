class ProductionUser < ApplicationRecord
  belongs_to :user
  belongs_to :production
  
  validates :role, presence: true
end