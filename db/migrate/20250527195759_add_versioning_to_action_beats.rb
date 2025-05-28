class AddVersioningToActionBeats < ActiveRecord::Migration[7.1]
  def change
    add_column :action_beats, :is_active, :boolean, default: false
    add_column :action_beats, :version_number, :integer
    add_column :action_beats, :source_beat_id, :bigint

    add_index :action_beats, [:production_id, :scene_id, :number, :version_number]
    add_foreign_key :action_beats, :action_beats, column: :source_beat_id
  end
end
