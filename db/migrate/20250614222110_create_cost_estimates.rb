class CreateCostEstimates < ActiveRecord::Migration[7.1]
  def change
    create_table :cost_estimates do |t|
      t.float :rate
      t.float :margin
      t.float :gross
      t.float :net
      t.float :gross_average
      t.float :net_average
      t.text :notes
      t.text :ai_notes
      t.references :incentive, null: false, foreign_key: true
      t.references :sequence, null: false, foreign_key: true
      t.references :scene, null: false, foreign_key: true
      t.references :action_beat, null: false, foreign_key: true
      t.references :shot, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.references :fx, null: false, foreign_key: true
      t.references :assumption, null: false, foreign_key: true

      t.timestamps
    end
  end
end
