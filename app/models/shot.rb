class Shot < ApplicationRecord

  scope :active_versions, -> {
    where(is_active: true)
      .or(
        where(
          version_number:
            select('MAX(version_number)')
              .group(:number)
        )
      )
  }

  belongs_to :action_beat
  belongs_to :scene
  belongs_to :sequence
  belongs_to :script,   optional: true
  belongs_to :production
  has_many   :character_appearances, dependent: :nullify

  has_many :shot_assumptions, dependent: :destroy
  has_many :assumptions, through: :shot_assumptions

  has_many :shot_assets, dependent: :destroy
  has_many :assets, through: :shot_assets

  has_many :shot_fx, dependent: :destroy
  has_many :fxs, through: :shot_fx

  validates :number,          presence: true, numericality: { only_integer: true }
  validates :number,          uniqueness: { scope: :action_beat_id }
  validates :description,     presence: true
  validates :vfx,             inclusion: { in: %w[yes no] }
  validates :camera_angle,    presence: true, allow_blank: true
  validates :camera_movement, presence: true, allow_blank: true
  validates :color,
            length: { maximum: 30 },
            allow_blank: true

  before_validation :set_versioning_fields

  private

  def set_versioning_fields
    if script_id
      self.version_number ||= script.version_number
      prev = Shot.where(production_id: production_id,
                        action_beat_id: action_beat_id,
                        number: number)
                 .where('version_number < ?', version_number)
                 .order(version_number: :desc)
                 .first
      self.source_shot_id ||= prev&.id
    else
      max = Shot.where(production_id: production_id,
                       action_beat_id: action_beat_id,
                       number: number)
                .maximum(:version_number) || 0
      self.version_number ||= max + 1
    end
  end
end
