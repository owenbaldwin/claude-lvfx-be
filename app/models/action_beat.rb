class ActionBeat < ApplicationRecord

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

  belongs_to :scene
  belongs_to :sequence, optional: true
  belongs_to :script,   optional: true
  belongs_to :production

  has_many   :shots, dependent: :destroy
  has_many   :character_appearances, dependent: :nullify
  validates :number, presence: true, numericality: { only_integer: true }
  validates :number,
          uniqueness: { scope: [:scene_id, :version_number],
                        message: "has already been taken for this version" }
  validates :text,   presence: true
  validates :beat_type, inclusion: { in: %w[action dialogue] }
  validates :color,
            length: { maximum: 30 },
            allow_blank: true

  before_validation :set_versioning_fields

  before_create :bump_version_and_link_previous

  private

  def set_versioning_fields
    if script_id
      self.version_number ||= script.version_number
      prev = ActionBeat.where(production_id: production_id,
                              scene_id: scene_id,
                              number: number)
                       .where('version_number < ?', version_number)
                       .order(version_number: :desc)
                       .first
      self.source_beat_id ||= prev&.id
    else
      max = ActionBeat.where(production_id: production_id,
                             scene_id: scene_id,
                             number: number)
                      .maximum(:version_number) || 0
      self.version_number ||= max + 1
    end
  end

  def bump_version_and_link_previous
    # find all prior versions of this action beat number, in this scene
    prior = ActionBeat
      .where(production_id: production_id, scene_id: scene_id, number: number)
      .order(version_number: :desc)
      .first

    if prior
      # 1) bump version
      self.version_number = prior.version_number + 1
      # 2) link back to it
      self.source_beat_id = prior.id
      # 3) deactivate it
      prior.update_columns(is_active: false)
    else
      # first-ever version
      self.version_number = 1
    end

    # ensure the new one is active
    self.is_active = true
  end
end
