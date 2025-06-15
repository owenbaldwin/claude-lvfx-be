class AddProductionIdToIncentivesAndCostEstimates < ActiveRecord::Migration[7.1]
  def change
    # Add production_id columns as nullable first
    add_reference :incentives, :production, null: true, foreign_key: true
    add_reference :cost_estimates, :production, null: true, foreign_key: true

    # Populate production_id for existing records
    reversible do |dir|
      dir.up do
        # Update cost_estimates with production_id from their associated records
        CostEstimate.reset_column_information

        CostEstimate.find_each do |cost_estimate|
          production_id = nil

          if cost_estimate.sequence_id
            production_id = Sequence.find(cost_estimate.sequence_id).production_id
          elsif cost_estimate.scene_id
            production_id = Scene.find(cost_estimate.scene_id).production_id
          elsif cost_estimate.action_beat_id
            production_id = ActionBeat.find(cost_estimate.action_beat_id).production_id
          elsif cost_estimate.shot_id
            production_id = Shot.find(cost_estimate.shot_id).production_id
          elsif cost_estimate.asset_id
            production_id = Asset.find(cost_estimate.asset_id).production_id
          elsif cost_estimate.assumption_id
            production_id = Assumption.find(cost_estimate.assumption_id).production_id
          elsif cost_estimate.fx_id
            production_id = Fx.find(cost_estimate.fx_id).production_id
          end

          # If we still don't have a production_id, use the first available production
          production_id ||= Production.first&.id

          cost_estimate.update_column(:production_id, production_id) if production_id
        end
      end
    end

    # Make production_id non-nullable
    change_column_null :incentives, :production_id, false
    change_column_null :cost_estimates, :production_id, false
  end
end
