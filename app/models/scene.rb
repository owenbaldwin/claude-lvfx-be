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
  validates :color,
            length: { maximum: 30 },
            allow_blank: true

  before_validation :set_versioning_fields

  before_create :bump_version_and_link_previous

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


  def bump_version_and_link_previous
    # find all prior versions of this scene number, in this production
    prior = Scene
      .where(production_id: production_id, number: number)
      .order(version_number: :desc)
      .first

    if prior
      # 1) bump version
      self.version_number = prior.version_number + 1
      # 2) link back to it
      self.source_scene_id = prior.id
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
