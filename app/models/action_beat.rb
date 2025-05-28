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
  belongs_to :sequence
  belongs_to :script,   optional: true
  belongs_to :production

  has_many   :shots, dependent: :destroy

  validates :number, presence: true, numericality: { only_integer: true }
  validates :number, uniqueness: { scope: :scene_id }
  validates :text,   presence: true
  validates :beat_type, inclusion: { in: %w[action dialogue] }
  validates :color,     optional: true

  before_validation :set_versioning_fields

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
end
