class CreateCharacterAppearances < ActiveRecord::Migration[6.1]
  def change
    create_table :character_appearances do |t|
      t.references :character, null: false, foreign_key: true
      t.references :scene,       null: true,  foreign_key: true
      t.references :action_beat, null: true,  foreign_key: true
      t.references :shot,        null: true,  foreign_key: true

      t.timestamps
    end
  end
end
