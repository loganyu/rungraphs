class CreateRunners < ActiveRecord::Migration[6.1]
  def change
    create_table :runners do |t|
      t.string		:first_name
      t.string		:last_name
      t.integer		:birth_year
      t.string		:team
      t.string    :team_name
      t.string    :sex
      t.string    :full_name
      t.string    :city
      t.string    :state
      t.string    :country

      t.timestamps
    end

    add_index :runners, [:first_name, :last_name, :city]
  end
end
