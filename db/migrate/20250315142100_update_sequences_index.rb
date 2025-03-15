class UpdateSequencesIndex < ActiveRecord::Migration[7.1]
  def change
    # Remove the existing script_id + number uniqueness constraint
    remove_index :sequences, [:script_id, :number], if_exists: true

    # Add a new production_id + number uniqueness constraint
    add_index :sequences, [:production_id, :number], unique: true, name: 'index_sequences_on_production_id_and_number'
  end
end