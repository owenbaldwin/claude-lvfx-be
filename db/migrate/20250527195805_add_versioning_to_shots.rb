class AddVersioningToShots < ActiveRecord::Migration[7.1]
  def change
    add_column :shots, :version_number, :integer
    add_column :shots, :source_shot_id, :bigint

    add_index :shots, [:production_id, :scene_id, :number, :version_number]
    add_foreign_key :shots, :shots, column: :source_shot_id
  end
end
