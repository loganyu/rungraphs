class AddSlugToRace < ActiveRecord::Migration[6.1]
  def change
    add_column :races, :slug, :string
    add_index :races, :slug, unique: true
  end
end
