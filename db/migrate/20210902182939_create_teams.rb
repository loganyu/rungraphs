class CreateTeams < ActiveRecord::Migration[6.1]
  def change
    create_table :teams do |t|
      t.string		:name
      t.string    :team_name

      t.timestamps
    end
  end
end
