class CreateShotGenerations < ActiveRecord::Migration[7.1]
  def change
    create_table :shot_generations do |t|
      t.string :job_id
      t.references :production, null: false, foreign_key: true
      t.string :status
      t.text :error
      t.json :results_json

      t.timestamps
    end
    add_index :shot_generations, :job_id, unique: true
  end
end
