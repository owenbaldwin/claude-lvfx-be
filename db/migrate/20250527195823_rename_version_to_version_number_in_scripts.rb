class RenameVersionToVersionNumberInScripts < ActiveRecord::Migration[7.1]
  def change
    rename_column :scripts, :version, :version_number
    change_column :scripts, :version_number, 'integer USING CAST(version_number AS integer)'
  end

end
