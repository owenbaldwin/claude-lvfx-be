class ShotGeneration < ApplicationRecord
  belongs_to :production

  validates :job_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def in_progress?
    %w[pending processing].include?(status)
  end
end
