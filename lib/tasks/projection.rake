# require 'rubygems'
# require 'mechanize'
# require 'open-uri'
# require 'json'

=begin

rake 'projection:new[http://api.rtrt.me/events/NYRR-BRONX-10M-2021/profiles,4d7a9ceb0be65b3cc4948ee9,31131D3E84A707837E70,10.0,2021 Bronx 10 Mile,September 25 2021 8:00am,09/25/21]'

rake projection:new["http://api.rtrt.me/events/NYRR-HEALTHYKIDNEY-2019/profiles","4d7a9ceb0be65b3cc4948ee9","31131D3E84A707837E70","6.2","Healthy Kidney 10k","March 3rd 2019 9:00am","04/24/19"]

rake projection:new["https://api.rtrt.me/events/NYRR-BROOKLYN-2024/profiles","4d7a9ceb0be65b3cc4948ee9","6A2EE51883196E8E0639","13.1","Brooklyn Half","May 16th 2024 7:00am","05/16/24"]

rake projection:set_team_results["brooklyn-half"]

=end
desc "Create Race Projection"

namespace :projection do
  task :set_team_results, [:slug] => :environment do |t, arg|
    slug = arg[:slug]
    projected_race = ProjectedRace.where(:slug => slug).first
    projected_race.set_team_results
  end

  task :new, [:url, :apiid, :token, :distance, :name, :date_and_time, :date, :distance_string] => :environment do |t, arg|
    distance = arg[:distance]
    name = arg[:name]
    date_and_time = arg[:date_and_time]
    date = format_date(arg[:date])
    distance_string = arg[:distance_string]

    projected_race = ProjectedRace.create(name: name, date_and_time: date_and_time, distance: distance, date: date)
    create_new_result_projections(projected_race, arg[:url], arg[:apiid], arg[:token], distance_string)
    projected_race.save!
    projected_race.reload
    projected_race.set_team_results
  end

  def create_new_result_projections(projected_race, url, apiid, token, distance_string)
    start = 1
    params = {
      max: "1000",
      total: "1",
      failonmax: "0",
      appid: apiid,
      token: token,
      search: "",
      source: "webtracker",
      start: start
    }
    puts "requesting runners from #{start} to #{start + 999}"
    response = RestClient.post url, params, :content_type => "application/x-www-form-urlencoded", :accept => :json
    json_roster_data = /{.+}/.match(response)[0]
    json_data_hash = JSON.parse(json_roster_data)
    roster_data = json_data_hash["list"]

    total = json_data_hash["info"]["total"].to_i
    puts "total runners: #{total}"

    loop do
      start += 1000
      break if start > total

      puts "requesting runners from #{start} to #{start + 999}"
      params[:start] = start
      response = RestClient.post url, params, :content_type => "application/x-www-form-urlencoded", :accept => :json
      json_roster_data = /{.+}/.match(response)[0]
      json_data_hash = JSON.parse(json_roster_data)
      roster_data.concat(json_data_hash["list"])
    end

    counter = 0

    puts "total results: #{roster_data.count}"
    roster_data.each do |runner_info|
      if !distance_string.blank?
        if runner_info['race'] != distance_string
          next
        end
      end
      
      if projected_race.projected_results.any? do |projected_result|
        projected_result.first_name == runner_info['fname'] &&
        projected_result.last_name == runner_info['lname'] &&
        projected_result.city == runner_info['city']
      end

      if runner_info['bib'] < projected_result.bib
        projected_result.update("bib" => runner_info['bib'])
        projected_result.save!
        next
      end
    end
    counter += 1

    # create result
    projected_result = ProjectedResult.create(
        first_name: runner_info['fname'],
        last_name: runner_info['lname'],
        sex: runner_info['sex'],
        full_name: "#{runner_info['name']}",
        city: runner_info['city'],
        country: runner_info['country'],
        bib: runner_info['bib'],
        projected_race_id: projected_race.id
      )

    if runner_info['city']
      city = runner_info['city'].downcase
    else
      city = nil
    end

    if runner_info['fname'].nil? || runner_info['lname'].nil?
      puts "missing name for #{runner_info.inspect}"
      next
    end

    # add runner and projected time by team first
    runners = Runner.where(first_name: runner_info['fname'].downcase, last_name: runner_info['lname'].downcase, city: city).where.not(team: "0")

    if runners.empty?
      runners = Runner.where(first_name: runner_info['fname'].downcase, last_name: runner_info['lname'].downcase).where.not(team: "0")
    end

    if runners.empty?
      runners = Runner.where(first_name: runner_info['fname'].downcase, last_name: runner_info['lname'].downcase, city: city)
    end

    # if a runner changes cities or if runner with same name without city
    if runners.empty?
      runners = Runner.where(first_name: runner_info['fname'].downcase, last_name: runner_info['lname'].downcase).where.not(city: city)
    end

    if !runners.empty? && !runners[0].results.empty?
      runner = runners[0]

      projected_result.update("runner_id" => runner.id, "team" => runner.team, "state" => runner.state, "age" => Time.now.year - runner.birth_year)

      # exclude mile since AG not as accurate and check for AG% since 18 mile Tune Up does not have AG%order('ag_percent DESC')[0]
      best_result = runner.results.where.not(:ag_percent => nil).where.not(:distance => nil).where("(distance != 1.0 AND distance != 0.2) AND date > ?", 1.year.ago).order('ag_percent DESC')[0]

      # if still no best time, find the most recent race that is not the mile or 18 miler
      if best_result.nil?
        best_result = runner.results.where.not(:ag_percent => nil).where.not(:distance => nil).where("distance != 1.0 AND distance != 0.2").order('date DESC').first
      end

      # if still no best time, find the most recent race including the mile and 18 mile
      if best_result.nil?
        best_result = runner.results.where.not(:distance => nil).order('date DESC').first
      end

      puts counter
      puts runner.full_name

      if best_result.nil?
        puts "No best result: #{runner_info['name']} "
        next
      end

      # check type of result time
      if best_result.net_time && !best_result.net_time.blank?
        if /^\d\d.\d\d$/ =~ best_result.net_time
          best_result.net_time = '00:' + best_result.net_time
        end
        best_time = DateTime.parse(best_result.net_time)
      elsif best_result.finish_time && !best_result.finish_time.blank?
        if /^\d\d.\d\d$/ =~ best_result.finish_time
          best_result.finish_time = '00:' + best_result.finish_time
        end
        best_time = DateTime.parse(best_result.finish_time)
      elsif best_result.gun_time && !best_result.gun_time.blank?
        if /^\d\d.\d\d$/ =~ best_result.gun_time
          best_result.gun_time = '00:' + best_result.gun_time
        end
        best_time = DateTime.parse(best_result.gun_time)
      else
        next
      end

      puts "best_time #{best_time.hour}:#{(best_time.min)}:#{best_time.sec}"
      best_time_in_seconds = best_time.hour * 60 * 60 + best_time.min * 60 + best_time.sec
      puts "best_time_in_seconds #{best_time_in_seconds}"
      puts "projected_race.distance #{projected_race.distance}"
      puts "best_result.distance #{best_result.distance}"
      # calculate projected time with Riegel formula
      # http://www.runningforfitness.org/faq/rp
      # this doesn't translate well for women so trying 4% instead of 6%
      if runner.sex == "m"
        degradation_coefficient = 1.06
      else
        degradation_coefficient = 1.04
      end

      if projected_race.distance > best_result.distance
        # T2 = T1 x (D2/D1)^degradation_coefficient
        projected_time_in_seconds = best_time_in_seconds * ((projected_race.distance / best_result.distance )**degradation_coefficient)
      else
        # T1 = T2 / (D2/D1)^degradation_coefficient
        projected_time_in_seconds = best_time_in_seconds / ((best_result.distance / projected_race.distance )**degradation_coefficient)
      end

      puts "projected_time_in_seconds #{projected_time_in_seconds}"
      projected_time = "#{sprintf "%02d",(projected_time_in_seconds / 3600).floor}:#{sprintf "%02d", ((projected_time_in_seconds % 3600) / 60).floor}:#{sprintf "%02d", ((projected_time_in_seconds % 3600) % 60).round}"
      puts "projected_time #{projected_time}"
      projected_pace_in_seconds = projected_time_in_seconds / projected_race.distance
      projected_pace = "#{sprintf "%02d", (projected_pace_in_seconds / 60).floor}:#{sprintf "%02d", ((projected_pace_in_seconds % 3600) % 60).round}"
      projected_result.update("net_time" => projected_time, "pace_per_mile" => projected_pace, "ag_percent" => best_result.ag_percent)
    else
      puts "Not found: #{runner_info['name']} "
      projected_result.update("team" => '---')
    end

    puts

    projected_result.save!
  end
end

def format_date(date_str)
  date = Date.strptime(date_str, '%m/%d/%y')
end
end

