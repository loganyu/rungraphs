class CreateProjectedRaces < ActiveRecord::Migration[6.1]
  def change
    enable_extension "hstore"

    create_table :projected_races do |t|
      t.string    :name
      t.date      :date
      t.float     :distance
      t.integer   :temperature
      t.integer   :humidity
      t.string    :date_and_time
      t.string    :location
      t.string    :weather
      t.string    :sponsor
      t.boolean   :club_points, default: false
      t.hstore    :men_results, array: true
      t.hstore    :women_results, array: true
      t.hstore    :men_40_results, array: true
      t.hstore    :women_40_results, array: true
      t.hstore    :men_50_results, array: true
      t.hstore    :women_50_results, array: true
      t.hstore    :men_60_results, array: true
      t.hstore    :women_60_results, array: true
      t.hstore    :men_70_results, array: true
      t.hstore    :women_70_results, array: true

      t.timestamps
    end
  end
end
