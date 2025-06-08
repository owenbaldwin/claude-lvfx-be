class CreateScriptParses < ActiveRecord::Migration[7.1]
  def change
    create_table :script_parses do |t|
      t.string :job_id
      t.references :production, null: false, foreign_key: true
      t.references :script, null: false, foreign_key: true
      t.string :status
      t.text :error
      t.json :results_json

      t.timestamps
    end
    add_index :script_parses, :job_id, unique: true
  end
end
