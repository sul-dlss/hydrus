class AddHideToObjectFile < ActiveRecord::Migration

  def change
    add_column(:object_files, :hide, :boolean, :default => false)
  end

end