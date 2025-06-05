class Production < ApplicationRecord
  has_many :production_users, dependent: :destroy
  has_many :users, through: :production_users
  has_many :scripts, dependent: :destroy
  has_many :sequences, dependent: :destroy
  has_many :scenes, dependent: :destroy
  has_many :scenes_through_seq,  through: :sequences, source: :scenes
  has_many :action_beats, dependent: :destroy
  has_many :shots, dependent: :destroy
  has_many :characters, dependent: :destroy
  has_many :character_appearances, dependent: :destroy
  has_many :complexities, dependent: :destroy
  has_many :assumptions, dependent: :destroy
  has_many :assets, dependent: :destroy
  has_many :fxs, dependent: :destroy

  validates :title, presence: true
end
