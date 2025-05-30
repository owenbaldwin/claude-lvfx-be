class Script < ApplicationRecord
  belongs_to :production
  has_many   :sequences,    dependent: :destroy
  has_many   :scenes,       through: :sequences
  has_many   :action_beats, through: :scenes
  has_many   :shots,        through: :action_beats


  before_validation :assign_version_and_previous

  has_one_attached :file

  private

  def assign_version_and_previous
    # default version_number to max+1 if blank
    if version_number.blank?
      max = production.scripts.maximum(:version_number) || 0
      self.version_number = max + 1
    end

    # link to previous script
    last = production.scripts.where.not(id: id)
                              .order(version_number: :desc)
                              .first
    self.previous_script_id ||= last&.id
  end
end
