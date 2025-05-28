class AddVersioningToSequences < ActiveRecord::Migration[7.1]
  def change
    add_column :sequences, :version_number, :integer
    add_column :sequences, :source_sequence_id, :bigint

    add_index :sequences, [:production_id, :number, :version_number]
    add_foreign_key :sequences, :sequences, column: :source_sequence_id
  end
end
