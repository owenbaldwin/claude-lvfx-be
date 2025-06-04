class AddScenesDataJsonToScripts < ActiveRecord::Migration[7.0]
  def change
    add_column :scripts, :scenes_data_json, :jsonb, default: {}
  end
end
