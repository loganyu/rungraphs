# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_09_10_174734) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "plpgsql"

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "projected_races", force: :cascade do |t|
    t.string "name"
    t.date "date"
    t.float "distance"
    t.integer "temperature"
    t.integer "humidity"
    t.string "date_and_time"
    t.string "location"
    t.string "weather"
    t.string "sponsor"
    t.boolean "club_points", default: false
    t.hstore "men_results", array: true
    t.hstore "women_results", array: true
    t.hstore "men_40_results", array: true
    t.hstore "women_40_results", array: true
    t.hstore "men_50_results", array: true
    t.hstore "women_50_results", array: true
    t.hstore "men_60_results", array: true
    t.hstore "women_60_results", array: true
    t.hstore "men_70_results", array: true
    t.hstore "women_70_results", array: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "slug"
    t.index ["slug"], name: "index_projected_races_on_slug", unique: true
  end

  create_table "projected_results", force: :cascade do |t|
    t.string "last_name"
    t.string "first_name"
    t.string "full_name"
    t.string "sex"
    t.integer "age"
    t.integer "bib"
    t.string "team"
    t.string "team_name"
    t.string "city"
    t.string "state"
    t.string "country"
    t.integer "overall_place"
    t.integer "gender_place"
    t.integer "age_place"
    t.string "net_time"
    t.string "pace_per_mile"
    t.string "ag_time"
    t.integer "ag_gender_place"
    t.float "ag_percent"
    t.integer "runner_id"
    t.integer "projected_race_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["projected_race_id"], name: "index_projected_results_on_projected_race_id"
    t.index ["runner_id"], name: "index_projected_results_on_runner_id"
  end

  create_table "races", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.date "date"
    t.float "distance"
    t.integer "temperature"
    t.integer "humidity"
    t.string "date_and_time"
    t.string "location"
    t.string "weather"
    t.string "sponsor"
    t.boolean "club_points", default: false
    t.hstore "men_results", array: true
    t.hstore "women_results", array: true
    t.hstore "men_40_results", array: true
    t.hstore "women_40_results", array: true
    t.hstore "men_50_results", array: true
    t.hstore "women_50_results", array: true
    t.hstore "men_60_results", array: true
    t.hstore "women_60_results", array: true
    t.hstore "men_70_results", array: true
    t.hstore "women_70_results", array: true
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "slug"
    t.index ["slug"], name: "index_races_on_slug", unique: true
  end

  create_table "results", force: :cascade do |t|
    t.string "last_name"
    t.string "first_name"
    t.string "sex"
    t.integer "age"
    t.integer "bib"
    t.string "team"
    t.string "team_name"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "residence"
    t.integer "overall_place"
    t.integer "gender_place"
    t.integer "age_place"
    t.string "net_time"
    t.string "finish_time"
    t.string "gun_time"
    t.string "pace_per_mile"
    t.string "ag_time"
    t.integer "ag_gender_place"
    t.float "ag_percent"
    t.date "date"
    t.float "distance"
    t.string "split_5km"
    t.string "split_10km"
    t.string "split_15km"
    t.string "split_20km"
    t.string "split_25km"
    t.string "split_30km"
    t.string "split_35km"
    t.string "split_40km"
    t.string "split_131m"
    t.integer "runner_id"
    t.integer "race_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["race_id"], name: "index_results_on_race_id"
    t.index ["runner_id"], name: "index_results_on_runner_id"
  end

  create_table "runners", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "team"
    t.string "team_name"
    t.string "sex"
    t.string "full_name"
    t.string "city"
    t.string "state"
    t.string "country"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "slug"
    t.integer "birth_year"
    t.date "birthdate"
    t.index ["first_name", "last_name", "city"], name: "index_runners_on_first_name_and_last_name_and_city"
    t.index ["slug"], name: "index_runners_on_slug", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.string "name"
    t.string "team_name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "slug"
    t.index ["slug"], name: "index_teams_on_slug", unique: true
  end

end
