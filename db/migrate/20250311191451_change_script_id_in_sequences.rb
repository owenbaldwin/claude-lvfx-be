class ChangeScriptIdInSequences < ActiveRecord::Migration[7.1]
  def change
    change_column_null :sequences, :script_id, true
    change_column_null :scenes, :script_id, true
    change_column_null :action_beats, :script_id, true
    change_column_null :shots, :script_id, true
  end
end
