class CreateIncentives < ActiveRecord::Migration[7.1]
  def change
    create_table :incentives do |t|
      t.string :name
      t.float :percentage

      t.timestamps
    end
  end
end
