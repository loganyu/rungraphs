class CreateProjectedResults < ActiveRecord::Migration[6.1]
  def change
    create_table :projected_results do |t|
      t.string      :last_name
      t.string      :first_name
      t.string      :full_name
      t.string      :sex
      t.integer     :age
      t.integer     :bib
      t.string      :team
      t.string      :team_name
      t.string      :city
      t.string      :state
      t.string      :country
      t.integer     :overall_place
      t.integer     :gender_place
      t.integer     :age_place
      t.string      :net_time
      t.string      :pace_per_mile
      t.string      :ag_time
      t.integer     :ag_gender_place
      t.float       :ag_percent
      t.integer     :runner_id
      t.integer     :projected_race_id

      t.timestamps
    end

    add_index :projected_results, :runner_id
    add_index :projected_results, :projected_race_id
  end
end
