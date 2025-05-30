class ScriptSerializer < ActiveModel::Serializer
  # attributes :id, :title, :description, :version, :date, :created_at
  attributes :id,
             :title,
             :description,
             :version_number,
             :date,
             :color,
             :previous_script_id,
             :created_at,
             :file_url

  belongs_to :production
  has_many :sequences

  def file_url
    object.file.attached? ? Rails.application.routes.url_helpers.rails_blob_url(object.file, only_path: true) : nil
  end
end
