class SequenceSerializer < ActiveModel::Serializer
  attributes :id,
             :number,
             :name,
             :description,
             :created_at,
             :version_number,
             :source_sequence_id

  belongs_to :script
  has_many :scenes
end
