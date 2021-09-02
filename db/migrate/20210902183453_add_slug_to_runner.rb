class AddSlugToRunner < ActiveRecord::Migration[6.1]
  def change
    add_column :runners, :slug, :string
    add_index :runners, :slug, unique: true
  end
end
