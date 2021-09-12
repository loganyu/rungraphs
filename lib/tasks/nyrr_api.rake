desc "Get Race Results from NYRR"

namespace :nyrr do
  KILOMETERS_TO_MILES = 0.621371
  TOKEN = "898d6b6aef0e4887"
  HEADERS = {
    :token => TOKEN,
    :content_type => "application/x-www-form-urlencoded",
    :accept => :json
  }

  task :get_results, [:year, :update_runner_profiles, :send_race_reports] => :environment do |t, arg|
    if arg[:year].blank?
      year = Time.now.year
    else
      year = arg[:year]
    end

    if arg[:update_runner_profiles] == "false"
      update_runner_profiles = false
    else
      update_runner_profiles = true
    end

    if arg[:send_race_reports] == "false"
      send_race_reports = false
    else
      send_race_reports = true
    end

    params = {
      pageIndex: 1,
      pageSize: 100,
      searchString: year,
      sortColumn: "StartDateTime",
      sortDescending: 1,
    }

    url = "https://results.nyrr.org/api/events/search"
    
    response = post(url , params)
    races_data = response["response"]["items"]
    if update_runner_profiles
      races_data.reverse!
    end
    races_data.each do |race_data|
      if race_data["isVirtual"] == true
        next
      end
      race = Race.where(:code => race_data["eventCode"]).first
      # if there are no men_results, the job was interrupted and the scraping needs to be resumed
      if race.nil? || race.men_results.nil?
        retry_count = 0
        puts "scraping #{race_data["eventName"]}"
        begin
          puts "retry_count #{retry_count}"
          upsert_race_data(race_data["eventCode"], update_runner_profiles, send_race_reports)
        rescue => error
          puts error
          puts error.backtrace
          retry_count += 1
          if retry_count < 10
            retry
          end
        end
      end
    end
  end

  task :get_result, [:race_code, :update_runner_profiles, :send_race_reports] => :environment do |t, arg|
    race_code = arg[:race_code]
    if arg[:update_runner_profiles] == "false"
      update_runner_profiles = false
    else
      update_runner_profiles = true
    end

    if arg[:send_race_reports] == "false"
      send_race_reports = false
    else
      send_race_reports = true
    end

    retry_count = 0
    begin
      puts "retry_count #{retry_count}"
      upsert_race_data(race_code, update_runner_profiles, send_race_reports)
    rescue
      retry_count += 1
      if retry_count < 10
        retry
      end
    end
  end
end

private

def upsert_race_data(race_code, update_runner_profiles, send_race_reports)
  # Get race info
  params = {
    eventCode: race_code
  }
  url = "https://results.nyrr.org/api/events/details"
  response = post(url, params)
  race_details = response["response"]

  race_name = race_details["eventName"]
  location = race_details["venue"]
  distance_unit_code = race_details["distanceUnitCode"]
  if distance_unit_code.match(/K/i)
    distance = (distance_unit_code.delete("Kk").to_f*KILOMETERS_TO_MILES).round(1)
  elsif distance_unit_code == "MAR"
    distance = 26.2
    return # skip for faster scraping
  elsif distance_unit_code == "HALF"
    distance = 13.1
  else
    distance = distance_unit_code.delete("Mm").to_f.round(1)
  end
  
  weather = race_details["weather"]
  if !weather.nil?
    temperature_regex = weather.match(/(\d+)\sDEGREES/i)
    if !temperature_regex.nil?
      temperature = temperature_regex[0].split(" ")[0].to_i
    else
      temperature = nil
    end
    humidity_regex = weather.match(/HUMIDITY\s(\d+)/i)
    if humidity_regex.nil?
      humidity_regex = weather.match(/(\d+)%\sHUMIDITY/i)
      if humidity_regex.nil?
        humidity = nil
      else
        humidity = humidity_regex[0].split(" ")[0].to_i
      end
    else
      humidity = humidity_regex[0].split(" ")[1].to_i
    end
  end

  start_date_time = race_details["startDateTime"]
  date = Date.parse(start_date_time)
  date_and_time = DateTime.parse(start_date_time).strftime("%B %-d, %Y, %-H:%M %p")

  puts "race_name: #{race_name}"
  puts "location: #{location}"
  puts "distance #{distance}"
  puts "weather #{weather}"
  puts "temperature #{temperature}"
  puts "humidity #{humidity}"
  puts "date #{date}"
  puts "date_and_time #{date_and_time}"

  race_params = {
    :name => race_name,
    :date => date,
    :distance => distance,
    :date_and_time => date_and_time,
    :location => location,
    :weather => weather,
    :temperature => temperature,
    :humidity => humidity,
    :code => race_code
  }
  race = Race.where(race_params).first
  if race.nil?
    race = Race.create(race_params)
  end

  total_results_count = 0
  team_code_by_team_name = {}
  index = 1
  loop do
      # Upsert teams info
    params = {
      eventCode: race_code,
      pageIndex: index,
      pageSize: 100,
      searchWord: "",
      sortColumn: "TeamName",
      sortDescending: false
    }
    url = "https://results.nyrr.org/api/teams/search"
    response = post(url , params)
    teams_data = response["response"]["items"]
    teams_data.each do |team_data|
      team = Team.where(:name => team_data["teamCode"].downcase).first
      if team.nil?
        Team.create(:name => team_data["teamCode"].downcase, :team_name => team_data["teamName"])
      else
        if team.team_name.nil?
          team.team_name = team_data["teamName"]
          team.save
        end
      end
      team_code_by_team_name[team_data["teamName"]] = team_data["teamCode"].downcase
    end
    total_results_count += teams_data.count
    if total_results_count >= response["response"]["totalItems"]
      break
    end 
    index += 1
  end

  # Get results
  genders = ["M", "F", "X"]
  age_ranges = [[8,14], [15,19],[20,24],[25,29],[30,34],[35,39],[40,44],[45,49],[50,54],[55,59],[60,100]]
  age_ranges.each do |age_range|
    if Result.where(race_id: race.id).where("age > ?", age_range[1]).exists?
      puts "skipping age_range #{age_range}"
      next
    end
    genders.each do |gender|
      if gender == "M" && Result.where(race_id: race.id).where("age >= ?", age_range[0]).where(sex: "F").exists?
        puts "skipping gender M age_range #{age_range}"
        next
      end
      if gender == "F" && Result.where(race_id: race.id).where("age >= ?", age_range[0]).where(sex: "X").exists?
        puts "skipping gender F age_range #{age_range}"
        next
      end
      results = Result.where(race_id: race.id).
        where("age >= ?", age_range[0]).
        where("age <= ?", age_range[1]).
        where(sex: gender.downcase).count
      current_results_count = results - results % 100
      index = current_results_count / 100 + 1
      runner_index = current_results_count + 1
      loop do
        puts "--------------------- index #{index} ---------------------"
        params = {
          eventCode: race_code,
          runnerId: nil,
          searchString: nil,
          handicap: nil,
          city: nil,
          pageIndex: index,
          pageSize: 51,
          sortColumn: "overallTime",
          sortDescending: false,
          gender: gender,
          ageFrom: age_range[0],
          ageTo: age_range[1],
        }
        url = "https://results.nyrr.org/api/runners/finishers-filter"
        response = post(url, params)
        total_results = response["response"]["totalItems"]
        results_data = response["response"]["items"]

        current_results_count += results_data.count
        index += 1

        results_data.each do |result_data|
          params = {
            runnerId: result_data["runnerId"]
          }
          url = "https://results.nyrr.org/api/runners/resultDetails"
          response = post(url, params)
          runner_details_data = response["response"]
          if runner_details_data.nil?
            next
          end

          net_time = runner_details_data["netTime"]
          if net_time == "0:00:00"
            net_time = nil
          end

          team = team_code_by_team_name[runner_details_data["teamName"]]
          if team.blank?
            team = 0
          end

          result_params = {
            :first_name => result_data["firstName"].try(:downcase),
            :last_name => result_data["lastName"].try(:downcase),
            :city => result_data["city"].try(:downcase),
            :state => result_data["stateProvince"].try(:downcase),
            :country => result_data["iaaf"].try(:downcase),
            :distance => race.distance,
            :date => race.date,
            :bib => result_data["bib"],
            :sex => result_data["gender"].try(:downcase),
            :age => result_data["age"],
            :team => team,
            :team_name => runner_details_data["teamName"],
            :net_time => add_leading_zero_to_time(net_time),
            :gun_time => add_leading_zero_to_time(runner_details_data["gunTime"]),
            :pace_per_mile => runner_details_data["pace"],
            :overall_place => runner_details_data["placeOverall"],
            :gender_place => runner_details_data["placeGender"],
            :ag_gender_place => runner_details_data["placeAgeGrade"],
            :age_place => runner_details_data["placeAgeGroup"],
            :ag_time => add_leading_zero_to_time(runner_details_data["timeAgeGrade"]),
            :ag_percent => runner_details_data["percentAgeGrade"]
          }

          result = Result.where(result_params).first
          if result
            puts "already exists: #{date} - #{race.name} - #{runner_index} - #{gender} - #{age_range} - #{result.team} - #{result.overall_place}: #{result.first_name} #{result.last_name}"
            runner_index += 1
            next
          end
          result = Result.new(result_params)

          #create or find runner
          birthdate = result_data["birthdate"] ? result_data["birthdate"].to_date : nil
          if result.age 
            birth_year = race.date.year - result.age
          else
            birth_year = nil
          end
          
          
          runners = Runner.where(first_name: result.first_name, last_name: result.last_name, birthdate: birthdate)

          if runners.empty?
            result_runner = Runner.create(
              first_name: result.first_name,
              last_name: result.last_name,
              birth_year: birth_year,
              birthdate: birthdate,
              team: result.team,
              team_name: result.team_name,
              sex: result.sex,
              full_name: "#{result.first_name} #{result.last_name}",
              city: result.city,
              state: result.state,
              country: result.country
            )
          else
            found = false
            runners.each do |runner|
              if runner.birth_year && runner.birth_year.between?(birth_year - 1, birth_year + 1) && runner.city == result.city && runner.team == result.team
                result_runner = runner
                found = true
                break
              end
            end
        
            if not found
              runners.each do |runner|
                if runner.birth_year && runner.birth_year.between?(birth_year - 1, birth_year + 1) && runner.city == result.city
                  result_runner = runner
                  found = true
                  break
                end
              end
            end

            if not found
              runners.each do |runner|
                if runner.birth_year && runner.birth_year.between?(birth_year - 1, birth_year + 1)
                  result_runner = runner
                  found = true
                  break
                end
              end
            end

            if not found
              result_runner = Runner.create(
                first_name: result.first_name,
                last_name: result.last_name,
                birth_year: birth_year,
                birthdate: result_data["birthdate"] ? result_data["birthdate"].to_date : nil,
                team: result.team,
                sex: result.sex,
                full_name: "#{result.first_name} #{result.last_name}",
                city: result.city,
                state: result.state,
                country: result.country
              )
            else
              # change runner team to latest if scraping new results
              if update_runner_profiles == true
                result_runner.update("team" => result.team)
                result_runner.update("city" => result.city)
                result_runner.update("state" => result.state)
                result_runner.update("country" => result.country)
              end
            end
          end

          result_runner.save!

          result.update("runner_id" => result_runner.id, "race_id" => race.id)
          puts "#{date} #{race.name} - #{runner_index} - #{gender} - #{age_range} - #{result.team} - #{result.overall_place}: #{result.first_name} #{result.last_name}"
          runner_index += 1
        end

        if current_results_count >= total_results
          break
        end
      end
    end
  end

  team_champs = false
  if race.name.match(/team champ/i)
    team_champs = true
  end
  race.set_team_results(team_champs)

  if send_race_reports
    NyrrRaceResultsMailer.team_results_report('nbr', race.slug, "rungraphs-reports@googlegroups.com", team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('qdr', race.slug, ['yu.logan@gmail.com', 'Qdrunners@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('dwrt', race.slug, ['yu.logan@gmail.com', 'dashingwhippets@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('cptc', race.slug, ['yu.logan@gmail.com', 'almdavid@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('pptc', race.slug, ['yu.logan@gmail.com', 'communications@pptc.org'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('nyac', race.slug, ['yu.logan@gmail.com', 'gian.caccia@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('btr', race.slug, ['yu.logan@gmail.com', 'james.c.chu@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('dpn', race.slug, ['yu.logan@gmail.com', 'white.kalliope@gmail.com', 'ns669@cornell.edu', 'cm10003@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.team_results_report('mhrc', race.slug, ['yu.logan@gmail.com', 'jess.jonesr@gmail.com'], team_champs).deliver_now
    NyrrRaceResultsMailer.unattached_brooklyn_runners_report(race.slug).deliver_now
    NyrrRaceResultsMailer.local_competitive_qualifiers_report('nbr', race.slug, ['yu.logan@gmail.com', 'menslocalcompetitive@northbrooklynrunners.org', 'womenslocalcompetitive@northbrooklynrunners.org']).deliver_now
  end
end

# if time field is missing a leading zero, add it here so sorting will work
def add_leading_zero_to_time(time)
  if time =~ /^\d\d:\d\d$/
    return "0:#{time}"
  else
    return time
  end
end

def post(url, params)
  begin
    retries ||= 3
    response = JSON.parse(RestClient.post(url, params, HEADERS))
    return response
  rescue => e
    retries -= 1
    puts "Error making request. retries left: #{retries} url: #{url}. params: #{params}. Error: #{e}"
    puts e.backtrace
    if retries > 0
      sleep(10)
      retry
    end
  end
end