class RacesController < ApplicationController
  before_action :set_race, only: [:show, :edit, :update, :destroy]

  # GET /races
  # GET /races.json
  def index
    if params[:year]
      year = params[:year]
    else
      year = Time.now.year
    end

    @races = Race.where('extract(year from date) = ?', year).select(:name, :distance, :date, :slug).order(:date => :desc)

    respond_to do |format|
      format.html
      format.json { render :json => {:success => true, :html => (render_to_string "races/_race_list", :formats => [:html], :layout => false, :locals => { races: @races } ) } }
    end
  end

  # GET /races/1
  # GET /races/1.json
  def show
    @race_time_array = get_race_time_title_and_type(@race)

    @results = []
    if @race.men_results && @race.women_results
      @men_results = @race.men_results.take(10)
      @women_results = @race.women_results.take(10)

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

    if @race.men_40_results && @race.women_40_results

      @men_40_results = @race.men_40_results.take(5)
      @women_40_results = @race.women_40_results.take(5)

      if @men_results.count < 5
        @men_40_teams_to_display = @men_40_results.count
      else
        @men_40_teams_to_display = 5
      end
      if @women_40_results.count < 5
        @women_40_teams_to_display = @women_40_results.count
      else
        @women_40_teams_to_display = 5
      end

      @results << {:men => @men_40_results, :women => @women_40_results, :men_teams => @men_40_teams_to_display, :women_teams => @women_40_teams_to_display, :title => "Masters 40+ Team Results", :score_count => 3}
    end

    if @race.men_50_results && @race.women_50_results

      @men_50_results = @race.men_50_results.take(5)
      @women_50_results = @race.women_50_results.take(5)

      if @men_50_results.count < 5
        @men_50_teams_to_display = @men_50_results.count
      else
        @men_50_teams_to_display = 5
      end
      if @women_50_results.count < 5
        @women_50_teams_to_display = @women_50_results.count
      else
        @women_50_teams_to_display = 5
      end

      @results << {:men => @men_50_results, :women => @women_50_results, :men_teams => @men_50_teams_to_display, :women_teams => @women_50_teams_to_display, :title => "Masters 50+ Team Results", :score_count => 3}
    end

    if @race.men_60_results && @race.women_60_results
      @men_60_results = @race.men_60_results.take(5)
      @women_60_results = @race.women_60_results.take(5)

      if @men_60_results.count < 5
        @men_60_teams_to_display = @men_60_results.count
      else
        @men_60_teams_to_display = 5
      end
      if @women_60_results.count < 5
        @women_60_teams_to_display = @women_60_results.count
      else
        @women_60_teams_to_display = 5
      end

      @results << {:men => @men_60_results, :women => @women_60_results, :men_teams => @men_60_teams_to_display, :women_teams => @women_60_teams_to_display, :title => "Masters 60+ Team Results", :score_count => 3}
    end

    if @race.men_70_results && @race.women_70_results
      @men_70_results = @race.men_70_results.take(5)
      @women_70_results = @race.women_70_results.take(5)

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

      @results << {:men => @men_70_results, :women => @women_70_results, :men_teams => @men_70_teams_to_display, :women_teams => @women_70_teams_to_display, :title => "Masters 70+ Team Results", :score_count => 3}
    end
  end

  # GET /races/new
  def new
    @race = Race.new
  end

  # GET /races/1/edit
  def edit
  end

  # POST /races
  # POST /races.json
  def create
    @race = Race.new(race_params)

    respond_to do |format|
      if @race.save
        format.html { redirect_to @race, notice: 'Race was successfully created.' }
        format.json { render :show, status: :created, location: @race }
      else
        format.html { render :new }
        format.json { render json: @race.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /races/1
  # PATCH/PUT /races/1.json
  def update
    respond_to do |format|
      if @race.update(race_params)
        format.html { redirect_to @race, notice: 'Race was successfully updated.' }
        format.json { render :show, status: :ok, location: @race }
      else
        format.html { render :edit }
        format.json { render json: @race.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /races/1
  # DELETE /races/1.json
  def destroy
    @race.destroy
    respond_to do |format|
      format.html { redirect_to races_url, notice: 'Race was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def get_race_results
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
      "age_range" => params[:age_range],
      "city" => ""
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
        FROM results
        LEFT JOIN runners as runner
        ON results.runner_id = runner.id
        WHERE results.race_id = (
          SELECT id
          FROM races
          WHERE races.slug = '#{race_slug}'
        )
      "

    if !searches["city"].blank?
      sql_search += "AND results.city LIKE '%#{searches["city"]}%'"
    end

    if !searches["full_name"].blank?
      searches["full_name"].split(' ').each do |search_term|
        sql_search += "AND runner.first_name || runner.last_name LIKE '%#{search_term}%'"
      end
    end

    if !searches["team"].blank?
      sql_search += "AND results.team LIKE '#{searches["team"]}'"
    end

    if !searches["sex"].blank?
      sql_search += "AND results.sex LIKE '#{searches["sex"]}'"
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


    results = Result.find_by_sql(sql_results)
    results = results.map do |result|
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
      recordsTotal: Race.find_by_slug(params[:id]).results.count,
      recordsFiltered: filtered_results_count,
      data: results.as_json
    }

    render json: response
  end

  def get_teams
    teams = Race.find_by_slug(params[:id]).results.pluck(:team).uniq
    teams.delete(nil)

    render json: teams.sort.as_json
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_race
        @race = Race.friendly.find_by_slug!(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def race_params
      params[:race]
    end

    def get_race_time_title_and_type(race)
      if race.results.first.nil? || race.results.first.net_time
        ["Net Time", "net_time"]
      elsif race.results.first.finish_time
        ["Finish Time", "finish_time"]
      else
        ["Gun Time", "gun_time"]
      end
    end
end
