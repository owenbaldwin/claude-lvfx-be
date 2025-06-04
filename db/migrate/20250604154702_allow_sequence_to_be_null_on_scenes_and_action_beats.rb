class AllowSequenceToBeNullOnScenesAndActionBeats < ActiveRecord::Migration[7.1]
  def change
    # Drop the NOT NULL constraint on scenes.sequence_id
    change_column_null :scenes, :sequence_id, true

    # Drop the NOT NULL constraint on action_beats.sequence_id
    change_column_null :action_beats, :sequence_id, true
  end
end
