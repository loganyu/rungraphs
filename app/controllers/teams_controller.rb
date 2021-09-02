class TeamsController < ApplicationController
	before_action :set_team, only: [:show]

  def index
  	@teams = Team.all.sort_by(&:name)
  end

  def show
  end

  def get_team_results
    draw = params[:draw]
    team_slug = params[:id]
    limit = params[:length]
    offset = params[:start]
    columns = params[:columns]
    asc_or_desc = params[:order]["0"][:dir]
    limit_one = params[:limit_one] == "true" ? true : false
    order_by_column = columns[params[:order]["0"][:column]][:data]
    searches = {
      "sex" => params[:sex],
      "full_name" => "",
      "age_range" => params[:age_range],
      "distance" => params[:distance]
    }

    columns.each do |col|
      if !col[1][:search][:value].empty?
        searches[col[1][:data]] = col[1][:search][:value].strip.downcase
      end
    end

    if limit_one
      sql_results = "WITH summary AS (SELECT results.*, COALESCE(results.net_time, results.finish_time, results.gun_time)
                                                                  as time, 
        runner.slug, runner.full_name, race.name as race_name, race.slug as race_slug, ROW_NUMBER() OVER(PARTITION BY results.runner_id ORDER BY results.net_time ASC) as rk"
      sql_filtered_count = sql_results
    else
      sql_results = "SELECT results.*, COALESCE(results.net_time, results.finish_time, results.gun_time)
                                                  as time, 
        runner.slug, runner.full_name, race.name as race_name, race.slug as race_slug"
      sql_filtered_count = " SELECT COUNT(results)"
    end
    sql_total_results_count = " SELECT COUNT(results)"

    

    sql_search =
      "
        FROM results
        LEFT JOIN runners as runner
        ON results.runner_id = runner.id
        LEFT JOIN races as race
        ON results.race_id = race.id
        WHERE results.team = '#{team_slug}'
      "

    sql_total_results_count += sql_search

    if !searches["full_name"].blank?
      searches["full_name"].split(' ').each do |search_term|
        sql_search += "AND results.first_name || results.last_name LIKE '%#{search_term}%'"
      end
    end

    if searches["sex"] != "all"
      sql_search += "AND results.sex LIKE '#{searches["sex"]}'"
    end

    sql_search += "AND results.distance = '#{searches["distance"]}'"

    if searches["age_range"] != 'all'
      min_age = 40
      max_age = 100
      sql_search += "AND results.age BETWEEN #{min_age} AND #{max_age}"
    end

    if limit_one
      sql_filtered_count += sql_search +
        "
          )
            SELECT COUNT(results)
            FROM summary results
            WHERE results.rk = 1
        "
      sql_search +=
        "
        )
          SELECT results.*
          FROM summary results
          WHERE results.rk = 1
        "
    else
      sql_filtered_count += sql_search
    end

    if order_by_column == "time"
      sql_search +=
        " 
          ORDER BY time
        "
    else
      sql_search +=
        " 
          ORDER BY results.#{order_by_column}
        "
    end

    sql_search +=
     "
      #{asc_or_desc}
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

    json_results = results.as_json

    filtered_results_count = ActiveRecord::Base.connection.execute(sql_filtered_count)[0]["count"]
    sql_total_results_count = ActiveRecord::Base.connection.execute(sql_total_results_count)[0]["count"]

    if asc_or_desc == "asc"
      overall_rank = 1 + offset.to_i
      json_results.each do |result|  
        result['overall_rank'] = overall_rank
        overall_rank += 1
      end
    else
      overall_rank = filtered_results_count.to_i - offset.to_i
      json_results.each do |result|
        result['overall_rank'] = overall_rank
        overall_rank -= 1
      end
    end
    
    response = {
      draw: draw,
      recordsTotal: sql_total_results_count,
      recordsFiltered: filtered_results_count,
      data: json_results
    }

    render json: response
  end

    private
    # Use callbacks to share common setup or constraints between actions.
    def set_team
        @team = Team.friendly.find_by_slug!(params[:id])
    end

    def team_params
      params[:team]
    end
end
