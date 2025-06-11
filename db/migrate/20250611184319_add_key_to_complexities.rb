class AddKeyToComplexities < ActiveRecord::Migration[7.1]
  def change
    add_column :complexities, :key, :string
    add_index :complexities, :key, unique: true
  end
end
