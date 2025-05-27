class ScriptSerializer < ActiveModel::Serializer
  # attributes :id, :title, :description, :version, :date, :created_at
  attributes :id,
             :title,
             :description,
             :version_number,
             :date,
             :color,
             :previous_script_id,
             :created_at

  belongs_to :production
  has_many :sequences
end
