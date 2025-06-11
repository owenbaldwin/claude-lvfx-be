class FixComplexityKeyUniqueConstraint < ActiveRecord::Migration[7.1]
  def change
    # Remove the global unique index
    remove_index :complexities, :key

    # Add a production-scoped unique index
    add_index :complexities, [:production_id, :key], unique: true
  end
end
