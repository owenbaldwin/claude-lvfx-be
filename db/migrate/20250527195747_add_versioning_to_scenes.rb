class AddVersioningToScenes < ActiveRecord::Migration[7.1]
  def change
    add_column :scenes, :is_active, :boolean, default: false
    add_column :scenes, :version_number, :integer
    add_column :scenes, :source_scene_id, :bigint

    add_index :scenes, [:production_id, :number, :version_number]
    add_foreign_key :scenes, :scenes, column: :source_scene_id
  end
end
