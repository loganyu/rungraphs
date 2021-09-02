require_relative '../../config/initializers/constant'

namespace :nyrr_results do
  task :get_results => :environment do |t, arg|
    races_page = Watir::Browser.new :phantomjs, args: %w[headless disable-gpu]
    # races_page = Watir::Browser.new :chrome, args: %w[headless disable-gpu]
    races_page.goto('http://results.nyrr.org/races')
    race_divs = races_page.divs(class: ['event-col-3'])
    loop do
      if !race_divs.nil?
        break
      end
    end
    race_divs.reverse_each do |race_div|
      race_name = race_div.div(class: "name").text
      race_date = race_div.parent.span(class: "date").text
      race = Race.where(:name => race_name).first
      if race.nil?
        race_link = race_div.a.href
        puts "scraping #{race_name} #{race_date}"
        scrape_race(race_link, race_date, true)
      end
    end

    races_page.close()
  end

  task :get_result, [:race_link, :update_runner_profiles] => :environment do |t, arg|
    race_link = arg[:race_link]
    if arg[:update_runner_profiles] == "true"
      update_runner_profiles = true
    else
      update_runner_profiles = false
    end
    scrape_race(race_link, nil, update_runner_profiles)
  end
end

private

def scrape_race(race_link, race_date = nil, update_runner_profiles = false)
  race_page = Watir::Browser.new :phantomjs, args: %w[headless disable-gpu]
  # race_page = Watir::Browser.new :chrome, args: %w[headless disable-gpu]
  race_page.goto(race_link)

  # It seems like ads don't appear with PhantomJS, but leaving this in case I need to
  # use chrome to debug
  # ad_links_close_buttons = race_page.as(class: ['footer-rms-ads-close'])
  # ad_links_close_buttons[0].click

  race_code = race_page.url.split('/')[-2]
  overview_browser = Watir::Browser.new :phantomjs, args: %w[headless disable-gpu]
  # overview_browser = Watir::Browser.new :chrome, args: %w[headless disable-gpu]
  overview_browser.goto("http://results.nyrr.org/event/#{race_code}/overview")
  loop do
    if !overview_browser.spans(class: 'feature-key', text: "DISTANCE").first.nil?
      break
    end
  end
  distance = overview_browser.spans(class: 'feature-key', text: "DISTANCE").first.parent.spans[1].text.sub(" MILES", "").to_i
  puts "distance #{distance}"
  date_and_time = overview_browser.spans(class: 'feature-key', text: "DATE/TIME").first.parent.p.text
  puts "date_and_time #{date_and_time}"
  location = overview_browser.spans(class: 'feature-key', text: "LOCATION").first.try(:parent).try(:p).try(:text)
  puts "location #{location}"
  weather = overview_browser.spans(class: 'feature-key', text: "WEATHER").first.try(:parent).try(:p).try(:text)
  puts "weather #{weather}"
  if !weather.nil?
    temperature_regex = weather.match(/(\d+)\sDEGREES/)
    if !temperature_regex.nil?
      temperature = temperature_regex[0].split(" ")[0].to_i
    else
      temperature = nil
    end
    humidity_regex = weather.match(/HUMIDITY\s(\d+)/)
    if humidity_regex.nil?
      humidity_regex = weather.match(/(\d+)%\sHUMIDITY/)
    end
    if !humidity_regex.nil?
      humidity = humidity_regex[0].split(" ")[1].to_i
    else
      humidity = nil
    end
  end
  race_name = overview_browser.div(class: 'event-page-header').h1.text
  puts "race_name #{race_name}"
  if !race_date.nil?
    date = Date.strptime(race_date, '%b %d, %Y')
  else
    date_regex = date_and_time.match(/^.+,\s\d{4}/)
    if !date_regex.nil?
      date_string = date_regex[0]
      date = Date.strptime(date_string, '%b %d, %Y')
    else
      date = nil
    end
  end
  overview_browser.close()

  next_links = race_page.as(class: ['button-load-more'])
  show_more_clicks_counter = 0
  tries = 3
  loop do
    show_more_clicks_counter += 1
    puts "Click 'SHOW MORE': #{show_more_clicks_counter} total clicks"
    begin
      next_links[1].click
      tries = 3
    rescue => e
      tries -= 1
      puts "error #{e.inspect}. tries left: #{tries}"
      if tries == 0
        puts "failed clicking show more link after retries. breaking out of loop"
        break
      end
    end
  end

  race = Race.create(
    :name => race_name,
    :date => date,
    :distance => distance,
    :date_and_time => date_and_time,
    :location => location,
    :weather => weather,
    :temperature => temperature,
    :humidity => humidity
  )
  team_code_by_team_name = TEAMS.invert

  expanded_results_browser = Watir::Browser.new :phantomjs
  # expanded_results_browser = Watir::Browser.new :chrome, args: %w[headless disable-gpu]
  race_page.divs(class: ['b-runner_results_active']).each do |runner_row|
    bib = runner_row.div(class: ['details']).spans[5].text
    puts "bib #{bib}"
    expanded_results_browser.goto("http://results.nyrr.org/event/#{race_code}/result/#{bib}")
    finisher = expanded_results_browser.divs(class: 'result-box').first
    loop do
      if !finisher.nil?
        break
      end
      finisher = expanded_results_browser.divs(class: 'result-box').first
      "get finisher again"
    end

    # finisher = finisher_divs.first
    # loop do
    #   if !finisher.nil?
    #     break
    #   end
    #   finisher = finisher_divs.first
    #   puts "get finisher again"
    # end
    # puts "finisher done"

    loop do
      if !finisher.divs(class: 'main-title')[0].blank?
        break
      end
    end
    full_name = finisher.divs(class: 'main-title')[0].text
    loop do
      if !full_name.blank?
        break
      end
      full_name = finisher.divs(class: 'main-title')[0].text
    end
    puts "full_name #{full_name}"
    first_name = full_name.split(" ")[0..-2].join(" ").downcase
    last_name = full_name.split(" ")[-1].downcase
    city = runner_row.div(class: 'race-distance').spans("ng-if" => "eventFinisher.city && eventFinisher.showUsa").first.try(:text).try(:downcase)
    puts "city #{city}"
    state = runner_row.div(class: 'race-distance').spans("ng-if" => "eventFinisher.stateProvince && eventFinisher.showUsa").first.try(:text).try(:downcase)
    puts "state #{state}"
    country = runner_row.div(class: 'race-distance').spans("ng-if" => "eventFinisher.iaaf").first.try(:text).try(:downcase)
    puts "country #{country}"
    sex_age = finisher.divs(class: 'main-title')[1].text.split(/\s+/)[1]
    puts "sex_age #{sex_age}"
    sex = sex_age[0].downcase
    age = sex_age[1..2].to_i
    team_name = finisher.divs(class: 'main-title')[2].inner_html.match(/<\/strong>.*<\/span>/)[0][9..-8]
    puts "team_name #{team_name}"
    if team_name.blank?
      team_code = 0
    else
      team_code = team_code_by_team_name[team_name].try(:downcase)
      if team_code.blank?
        team_code = "xxx"
      end
    end

    net_time = add_leading_zero_to_time(finisher.label(:text, "Official Time").parent.span.text)
    puts "net_time #{net_time}"
    pace_per_mile = finisher.label(:text, "Pace per Mile").parent.span.text
    puts "pace_per_mile #{pace_per_mile}"
    overall_place = finisher.label(:text, "Place Overall").parent.span.text.strip.delete(",")
    puts "overall_place #{overall_place}"
    gender_place = finisher.label(:text, "Place Gender").parent.span.text
    puts "gender_place #{gender_place}"
    ag_gender_place = finisher.label(:text, "Place Age‑Group").parent.span.text
    puts "ag_gender_place #{ag_gender_place}"
    ag_time = add_leading_zero_to_time(finisher.label(:text, "Time Age‑Graded").parent.span.text)
    puts "ag_time #{ag_time}"
    ag_percent = finisher.label(:text, "Percentile Age‑Graded").parent.span.text[0..-2].to_f
    puts "ag_percent #{ag_percent}"

    result = Result.new(
      :first_name => first_name,
      :last_name => last_name,
      :city => city,
      :state => state,
      :country => country,
      :distance => race.distance,
      :date => race.date,
      :bib => bib,
      :sex => sex,
      :age => age,
      :team => team_code,
      :team_name => team_name,
      :net_time => net_time,
      :pace_per_mile => pace_per_mile,
      :overall_place => overall_place,
      :gender_place => gender_place,
      :ag_gender_place => ag_gender_place,
      :ag_time => ag_time,
      :ag_percent => ag_percent
    )

    # find or create team
    team = Team.where(name: result.team)
    if !team.nil? && team.empty?
      Team.create(name: result.team)
    end

    #create or find runner
    if result.age
      birth_year = race.date.year - result.age
    else
      birth_year = ""
    end
    
    runners = Runner.where(first_name: result.first_name, last_name: result.last_name)

    if runners.empty?
      result_runner = Runner.create(
        first_name: result.first_name,
        last_name: result.last_name,
        birth_year: birth_year,
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
          result_runner.update_attributes("team" => result.team)
          result_runner.update_attributes("city" => result.city)
          result_runner.update_attributes("state" => result.state)
          result_runner.update_attributes("country" => result.country)
        end
      end
    end

    result_runner.save!

    result.update_attributes("runner_id" => result_runner.id, "race_id" => race.id)
    puts "#{race.name}- #{result.overall_place}: #{result.first_name} #{result.last_name}"
    puts "-----------------------------------------------------------------------------"
  end
  expanded_results_browser.close()
  race_page.close()

  race.set_team_results()
end

# if time field is missing a leading zero, add it here so sorting will work
def add_leading_zero_to_time(time)
  if time =~ /^\d\d:\d\d$/
    return "0:#{time}"
  else
    return time
  end
end

def update_teams(race_code)
  params = {
    eventCode: race_code,
    pageIndex: 1,
    pageSize: 1000,
    searchWord: "",
    sortColumn: "",
    sortDescending: ""
  }
  headers = {
    :username => "subscriber",
    :password => "umPrcNcZKuJ9TQ2",
    :content_type => :json,
    :accept => :json
  }
  response = JSON.parse(RestClient.post("http://results.nyrr.org/api/teams/search", params, headers))
end

def get_results(race_code)
  params = {
    eventCode: race_code,
    pageIndex: 2,
    pageSize: 1000,
    searchWord: "",
    sortColumn: "",
    sortDescending: true
  }
  headers = {
    :username => "subscriber",
    :password => "umPrcNcZKuJ9TQ2",
    :content_type => :json,
    :accept => :json
  }
  response = JSON.parse(RestClient.post("http://results.nyrr.org/api/runners/finishers", params, headers))
  response["response"]["items"]
end

