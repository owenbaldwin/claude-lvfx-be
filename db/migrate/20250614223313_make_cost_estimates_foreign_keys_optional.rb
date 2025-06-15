class MakeCostEstimatesForeignKeysOptional < ActiveRecord::Migration[7.1]
  def change
    change_column_null :cost_estimates, :incentive_id, true
    change_column_null :cost_estimates, :sequence_id, true
    change_column_null :cost_estimates, :scene_id, true
    change_column_null :cost_estimates, :action_beat_id, true
    change_column_null :cost_estimates, :shot_id, true
    change_column_null :cost_estimates, :asset_id, true
    change_column_null :cost_estimates, :fx_id, true
    change_column_null :cost_estimates, :assumption_id, true
  end
end
