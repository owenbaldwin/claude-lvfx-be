class RemoveOldUniqueIndexes < ActiveRecord::Migration[7.1]
  def change
    remove_index :scenes, name: "index_scenes_on_sequence_id_and_number"
    remove_index :sequences, name: "index_sequences_on_production_id_and_number"
    remove_index :shots, name: "index_shots_on_action_beat_id_and_number"
    remove_index :action_beats, name: "index_action_beats_on_scene_id_and_number"
  end

end
