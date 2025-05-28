class Sequence < ApplicationRecord

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

  belongs_to :script, optional: true
  belongs_to :production
  has_many   :scenes, dependent: :destroy

  validates :number, presence: true, numericality: { only_integer: true }
  validates :number, uniqueness: { scope: :production_id }
  validates :name,   presence: true
  validates :color,
            length: { maximum: 30 },
            allow_blank: true

  before_validation :set_versioning_fields

  private

  def set_versioning_fields
    if script_id
      self.version_number ||= script.version_number

      # find most recent same-number in this production
      prev = Sequence.where(production_id: production_id, number: number)
                     .where('version_number < ?', version_number)
                     .order(version_number: :desc)
                     .first
      self.source_sequence_id ||= prev&.id
    else
      max = Sequence.where(production_id: production_id, number: number)
                    .maximum(:version_number) || 0
      self.version_number ||= max + 1
    end
  end
end
