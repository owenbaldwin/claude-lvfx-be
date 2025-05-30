class Character < ApplicationRecord
  belongs_to :production
  has_many   :character_appearances, dependent: :destroy

end
