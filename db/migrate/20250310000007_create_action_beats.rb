class CreateActionBeats < ActiveRecord::Migration[7.0]
  def change
    create_table :action_beats do |t|
      t.references :scene, null: false, foreign_key: true
      t.text :description, null: false
      t.integer :order_number
      t.text :dialogue
      t.text :notes

      t.timestamps
    end
  end
end