class ProjectedRacesController < ApplicationController
  before_action :set_projected_race, only: [:show, :edit, :update, :destroy]

  # GET /projected_races
  # GET /projected_races.json
  def index
    @projected_races = ProjectedRace.all.select(:name, :distance, :date, :slug).order(:date => :desc)
  end

  # GET /projected_races/1
  # GET /projected_races/1.json
  def show
    @results = []
    if @projected_race.men_results && @projected_race.women_results
      @men_results = @projected_race.men_results
      @women_results = @projected_race.women_results

      if @men_results.count < 10
        @men_teams_to_display = @men_results.count
      else
        @men_teams_to_display = 10
      end
      if @women_results.count < 10
        @women_teams_to_display = @women_results.count
      else
        @women_teams_to_display = 10
      end

      @results << {:men => @men_results, :women => @women_results, :men_teams => @men_teams_to_display, :women_teams => @women_teams_to_display, :title => "Team Results", :score_count => 5}
    end

    if @projected_race.men_40_results && @projected_race.women_40_results

      @men_40_results = @projected_race.men_40_results
      @women_40_results = @projected_race.women_40_results

      if @men_results.count < 10
        @men_40_teams_to_display = @men_40_results.count
      else
        @men_40_teams_to_display = 10
      end
      if @women_40_results.count < 10
        @women_40_teams_to_display = @women_40_results.count
      else
        @women_40_teams_to_display = 10
      end

      @results << {:men => @men_40_results, :women => @women_40_results, :men_teams => @men_40_teams_to_display, :women_teams => @women_40_teams_to_display, :title => "Masters 40+ Team Results", :score_count => 3}
    end

    if @projected_race.men_50_results && @projected_race.women_50_results

      @men_50_results = @projected_race.men_50_results
      @women_50_results = @projected_race.women_50_results

      if @men_50_results.count < 10
        @men_50_teams_to_display = @men_50_results.count
      else
        @men_50_teams_to_display = 10
      end
      if @women_50_results.count < 10
        @women_50_teams_to_display = @women_50_results.count
      else
        @women_50_teams_to_display = 10
      end

      @results << {:men => @men_50_results, :women => @women_50_results, :men_teams => @men_50_teams_to_display, :women_teams => @women_50_teams_to_display, :title => "Masters 50+ Team Results", :score_count => 3}
    end

    if @projected_race.men_60_results && @projected_race.women_60_results
      @men_60_results = @projected_race.men_60_results
      @women_60_results = @projected_race.women_60_results

      if @men_60_results.count < 10
        @men_60_teams_to_display = @men_60_results.count
      else
        @men_60_teams_to_display = 10
      end
      if @women_60_results.count < 10
        @women_60_teams_to_display = @women_60_results.count
      else
        @women_60_teams_to_display = 10
      end

      @results <<{:men => @men_60_results, :women => @women_60_results, :men_teams => @men_60_teams_to_display, :women_teams => @women_60_teams_to_display, :title => "Masters 60+ Team Results", :score_count => 3}
    end

    if @projected_race.men_70_results && @projected_race.women_70_results
      @men_70_results = @projected_race.men_70_results.take(5)
      @women_70_results = @projected_race.women_70_results.take(5)

      if @men_70_results.count < 5
        @men_70_teams_to_display = @men_70_results.count
      else
        @men_70_teams_to_display = 5
      end
      if @women_70_results.count < 5
        @women_70_teams_to_display = @women_70_results.count
      else
        @women_70_teams_to_display = 5
      end

      @results <<{:men => @men_70_results, :women => @women_70_results, :men_teams => @men_70_teams_to_display, :women_teams => @women_70_teams_to_display, :title => "Masters 70+ Team Results", :score_count => 3}
    end
  end

  def get_projected_race_results
    draw = params[:draw]
    race_slug = params[:id]
    limit = params[:length]
    offset = params[:start]
    columns = params[:columns]
    asc_or_desc = params[:order]["0"][:dir]
    order_by_column = columns[params[:order]["0"][:column]][:data]
    searches = {
      "team" => "",
      "sex" => "",
      "full_name" => "",
      "age_range" => params[:age_range]
    }

    columns.each do |col|
      if !col[1][:search][:value].empty?
        searches[col[1][:data]] = col[1][:search][:value].strip.downcase
      end
    end

    sql_results = " SELECT results.*, runner.slug, runner.full_name"
    sql_filtered_count = " SELECT COUNT(results)"
    sql_search =
      "
        FROM projected_results as results
        LEFT JOIN runners as runner
        ON results.runner_id = runner.id
        WHERE results.projected_race_id = (
          SELECT id
          FROM projected_races
          WHERE projected_races.slug = '#{race_slug}'
        )
      "
    if !searches["full_name"].blank?
      searches["full_name"].split(' ').each do |search_term|
        sql_search += "AND runner.first_name || runner.last_name LIKE '%#{search_term}%'"
      end
    end

    if !searches["team"].blank?
      sql_search += "AND results.team LIKE '#{searches["team"]}'"
    end

    if !searches["sex"].blank?
      sql_search += "AND results.sex LIKE '#{searches["sex"].upcase}'"
    end

    if !searches["age_range"].blank?
      min_age = searches["age_range"][0..1]
      max_age = searches["age_range"][3..4]
      sql_search += "AND results.age BETWEEN #{min_age} AND #{max_age}"
    end

    sql_filtered_count += sql_search

    sql_search +=
    " 
      ORDER BY results.#{order_by_column} #{asc_or_desc}
        LIMIT #{limit}
        OFFSET #{offset};
    "

    sql_results += sql_search

    projected_results = Result.find_by_sql(sql_results)
    projected_results = projected_results.map do |result|
      if HIDDEN_RUNNERS.include?(result.slug)
        result.first_name = "?????"
        result.last_name = "?????"
        result.city = "?????"
        result.team = "?????"
        result.age = "?????"
        result.slug = ""
      end

      result
    end

    filtered_results_count = ActiveRecord::Base.connection.execute(sql_filtered_count)[0]["count"]

    response = {
      draw: draw,
      recordsTotal: ProjectedRace.find_by_slug(params[:id]).projected_results.count,
      recordsFiltered: filtered_results_count,
      data: projected_results.as_json
    }

    render json: response
  end

  def get_projected_teams
    teams = ProjectedRace.find_by_slug(params[:id]).projected_results.pluck(:team).uniq.compact.sort

    render json: teams.as_json
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_projected_race
        @projected_race = ProjectedRace.friendly.find_by_slug!(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def projected_race_params
      params[:projected_race]
    end
end
