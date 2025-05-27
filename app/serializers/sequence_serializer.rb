class SequenceSerializer < ActiveModel::Serializer
  attributes :id,
             :number,
             :name,
             :prefix,
             :description,
             :created_at,
             :version_number,
             :source_sequence_id,
             :is_active,
             :production_id,
             :script_id
  belongs_to :script
  has_many :scenes
end
