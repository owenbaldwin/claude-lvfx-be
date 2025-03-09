class CreateProductions < ActiveRecord::Migration[7.0]
  def change
    create_table :productions do |t|
      t.string :title, null: false
      t.text :description
      t.date :start_date
      t.date :end_date
      t.string :status, default: 'pre-production'

      t.timestamps
    end
  end
end