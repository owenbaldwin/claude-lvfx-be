class Shot < ApplicationRecord
  belongs_to :action_beat
  
  validates :number, presence: true
end