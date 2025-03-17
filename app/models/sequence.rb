class Sequence < ApplicationRecord
  belongs_to :script, optional: true
  belongs_to :production
  has_many :scenes, dependent: :destroy
  has_many :action_beats, through: :scenes
  has_many :shots, through: :action_beats

  validates :number, presence: true, numericality: { only_integer: true }
  validates :name, presence: true

  validates :number, uniqueness: { scope: :production_id, message: "must be unique within a production" }

  # before_save :reorder_sequences
  after_save :reorder_sequences


  private

  # Ensure sequence numbers remain contiguous and ordered
  def reorder_sequences
    return unless number_changed?

    sequences = production.sequences.order(:number)
    sequences.each_with_index do |seq, index|
      seq.update_column(:number, index + 1) unless seq.number == index + 1
    end
  end
end
