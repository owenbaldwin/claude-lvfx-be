class Scene < ApplicationRecord

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

  belongs_to :sequence
  belongs_to :script,   optional: true
  belongs_to :production
  has_many   :action_beats, dependent: :destroy

  validates :number,    presence: true, numericality: { only_integer: true }
  # validates :number,    uniqueness: { scope: :sequence_id }
  validates :number,
          uniqueness: { scope: [:production_id, :version_number],
                        message: "has already been taken for this version" }
  validates :location,  presence: true
  validates :int_ext,   inclusion: { in: %w[interior exterior] }
  validates :day_night, presence: true

  before_validation :set_versioning_fields

  private


  def set_versioning_fields
    if script_id
      self.version_number ||= script.version_number
      prev = Scene.where(production_id: production_id, number: number)
                  .where('version_number < ?', version_number)
                  .order(version_number: :desc)
                  .first
      self.source_scene_id ||= prev&.id
    else
      max = Scene.where(production_id: production_id, number: number)
                  .maximum(:version_number) || 0
      self.version_number ||= max + 1
    end
  end
end
