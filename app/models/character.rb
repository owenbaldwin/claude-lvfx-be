class Character < ApplicationRecord
  belongs_to :production
  has_many   :character_appearances, dependent: :destroy

  validates :full_name, presence: true
end
