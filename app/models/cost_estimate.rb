class CostEstimate < ApplicationRecord
  belongs_to :production
  belongs_to :incentive,    optional: true
  belongs_to :sequence,     optional: true
  belongs_to :scene,        optional: true
  belongs_to :action_beat,  optional: true
  belongs_to :shot,         optional: true
  belongs_to :asset,        optional: true
  belongs_to :fx,           optional: true
  belongs_to :assumption,   optional: true

  validates :rate, allow_nil: true, numericality: { greater_than: 0 }
  validates :margin, allow_nil: true, numericality: { greater_than: 0 }
  validates :gross, allow_nil: true, numericality: { greater_than: 0 }
  validates :net, allow_nil: true, numericality: { greater_than: 0 }
  validates :gross_average, allow_nil: true, numericality: { greater_than: 0 }
  validates :net_average, allow_nil: true, numericality: { greater_than: 0 }
end
