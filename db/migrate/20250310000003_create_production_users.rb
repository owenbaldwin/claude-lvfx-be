class CreateProductionUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :production_users do |t|
      t.references :user, null: false, foreign_key: true
      t.references :production, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    
    add_index :production_users, [:user_id, :production_id], unique: true
  end
end