namespace :nyrr do

  RESULT_PROPERTIES = {
  "Last Name" => "last_name",
  "First Name" => "first_name",
  "Bib" => "bib",
  "Team" => "team",
  "City" => "city",
  "State" => "state",
  "Country" => "country",
  "OverallPlace" => "overall_place",
  "GenderPlace" => "gender_place",
  "AgePlace" => "age_place",
  "FinishTime" => "finish_time",
  "PaceperMile" => "pace_per_mile",
  "AGTime" => "ag_time",
  "AGGenderPlace" => "ag_gender_place",
  "AG %" => "ag_percent",
  "NetTime" => "net_time",
  "GunTime" => "gun_time"
  }

  CLUB_POINTS = {
    "2014" => [1, 27, 37, 38, 41, 46, 48, 51, 57, 60],
    "2013" => [1, 14, 17, 20, 23, 29, 32, 37, 45, 48],
    "2012" => [4, 11, 16, 21, 23, 25, 31, 35, 41, 45],
    "2011" => [4, 17, 19, 23, 26, 30, 33, 39, 44],
    "2010" => [4, 16, 21, 26, 29, 35, 41, 47, 52],
    "2009" => [4, 18, 22, 28, 29, 31, 32, 38, 41, 46, 47]
  }

  # when scraping old race results, start from most recent to least recent to set teams to the most recent team
  task :old_results, [:year] => :environment do |t, arg|
    all_results_page = "http://web2.nyrrc.org/cgi-bin/start.cgi/aes-programs/results/resultsarchive.htm"
    yearly_results_page = get_yearly_results_page(all_results_page, arg[:year])
    scrape_yearly_results(yearly_results_page, arg[:year], "old")
  end

  task :new_results => :environment do |t, arg|
    year = Time.now.year
    all_results_page = "http://web2.nyrrc.org/cgi-bin/start.cgi/aes-programs/results/resultsarchive.htm"
    yearly_results_page = get_yearly_results_page(all_results_page, year)
    scrape_yearly_results(yearly_results_page, year, "new")
  end

  def get_yearly_results_page(all_results_page, year)
    $a.get(all_results_page).form_with(:name => "findOtherRaces") do |f|
      f["NYRRYEAR"] = year
    end.click_button
  end

  def scrape_yearly_results(yearly_results_page, year, type_of_result)
    puts "----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}----#{year}"
    race_links = get_race_links(yearly_results_page)
    race_dates = get_race_dates(yearly_results_page)

    # race_links = [race_links[24]]
    # race_dates = [race_dates[24]]

    # scrape from oldest to newest so the latest teams are set
    if type_of_result == "new"
      race_links.reverse!
      race_dates.reverse!
    end

    race_links.count.times do |i|
      # only including club points races because of size limits
      # next if !CLUB_POINTS[year].include? i

      # skip more fitness 2009 race since it's broken
      if ( year == "2009" && (i == 44 || i == 45) )
        puts "skipping More Fitness Half Marathon"
        next
      end

      scrape_individual_race_results(race_links[i], race_dates[i], year, type_of_result)
    end
  end

  def scrape_individual_race_results(link, date, year, type_of_result)
    # skip if race with same name and date exists
    if !Race.where(name: link.text, date: format_date(date)).empty?
      puts "Skipping #{date} #{link.text}"
      return
    end

    # click on individual race result page
    begin
      race_results_cover_page = $a.click(link)
    rescue
      puts "Error clicking #{date} #{link.text}"
      return
    end
    puts "---------Scraping Race #{date} #{link.text}---------"

    if race_results_cover_page.form.nil? || race_results_cover_page.form.radiobutton_with(:value => /500/).nil?
      puts "    ****Failed. Improper result form."
      return
    end

    # fill in form with 'Finishers in order' => 'All' and 'Maximum' => '500'
    race_results_page = race_results_cover_page.form do |f|
      f.radiobutton_with(:value => /500/).check
    end.click_button

    # cannot scrape data if format is different
    if get_rows(race_results_page).empty?
      puts "    ****Failed. Improper table format."
      return
    end

    begin
      race = Race.new
      race.name = link.text
      race.date = format_date(date)

      scrape_race_info(race_results_page, race)
      race.save!

      scrape_race_individual_page(race_results_page, race, type_of_result)
      race.set_team_results

      if type_of_result == "new"
        # email NBR result report
        NyrrRaceResultsMailer.team_results_report('nbr', race.slug).deliver_now
        NyrrRaceResultsMailer.team_results_report('qdr', race.slug, 'yu.logan@gmail.com').deliver_now
        NyrrRaceResultsMailer.team_results_report('dwrt', race.slug, 'yu.logan@gmail.com').deliver_now
        NyrrRaceResultsMailer.unattached_brooklyn_runners_report(race.slug).deliver_now
        NyrrRaceResultsMailer.local_competitive_qualifiers_report('nbr', race.slug, ['yu.logan@gmail.com', 'menslocalcompetitive@northbrooklynrunners.org', 'womenslocalcompetitive@northbrooklynrunners.org']).deliver_now
      end
    rescue
      puts "error creating new race #{race.name}"
      race.destroy
    end
  end

  def get_race_links(yearly_results_page)
    yearly_results_page.links.select{|link| link.href.match(/result.id=/)}
  end

  def get_race_dates(yearly_results_page)
    yearly_results_page.parser.xpath("//td[b]/p").text.split(/\r|\n/).reject{|el| el.strip.empty?}.map{|el| el[-8..-1]}
  end

  def get_rows(race_results_page)
    race_results_page.parser.xpath("//table[@cellpadding='3'][@cellspacing='0'][@border='1'][@bordercolor='#DDDDDD'][@style='border-collapse:collapse; border-color:#DDD']/tr")
  end

  def scrape_race_individual_page(race_results_page, race, type_of_result)
    i = 0
    
    loop do
      i += 1
      puts "--------------------------scraping page #{i}------------------------------"
      rows = get_rows(race_results_page)
      race_fields_array = []
      rows[0].css('td').each do |i|
        race_fields_array << i.text
      end

      # remove separate method because of stack problems with large races
      # scrape_result_rows(rows, race, race_fields_array)
      rows.shift
      rows.each do |row|
        result = Result.new(distance: race.distance, date: race.date)
        data_array = []
        row.css('td').each_with_index do |field, index|
          property = RESULT_PROPERTIES[race_fields_array[index]]
          if race_fields_array[index] == "Sex/Age"
            if !field.text.empty?
              result.update_attributes("sex" => field.text[0].downcase)
              result.update_attributes("age" => field.text[1..2].to_i)
            end
          # if time field is missing a leading zero, add it here so sorting will work
          elsif ["net_time", "finish_time", "gun_time", "ag_time"].include? property
            if field.text =~ /^\d\d:\d\d$/
              result.update_attributes(property => "0:" + field.text)
            else
              result.update_attributes(property => field.text)
            end
          elsif property
            if !field.text.empty?
              result.update_attributes(property => field.text.downcase)
            end
          end
        end

        next if !race.results.where(overall_place: result.overall_place).empty?

        if result.team.blank?
          result.team = 0
        end

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
            if type_of_result == "new"
              result_runner.update_attributes("team" => result.team)
              result_runner.update_attributes("city" => result.city)
              result_runner.update_attributes("state" => result.state)
              result_runner.update_attributes("country" => result.country)
            end
          end
        end

        result_runner.save!

        result.update_attributes("runner_id" => result_runner.id)
        result.update_attributes("race_id" => race.id)
        result.save!
        puts "#{race.name}- #{result.overall_place}: #{result.first_name} #{result.last_name}"
      end

      # # if there is a next button, click and add those results too
      next_500_link = race_results_page.parser.xpath("//a[text()='NEXT 500']")[0]

      # break unless next_500_link
      break if next_500_link.blank?

      race_results_page = $a.click(next_500_link)
    end
  end

  # def scrape_result_rows(rows, race, race_fields_array)
  #   rows.shift
  #   rows.each do |row|
  #     result = Result.new(distance: race.distance, date: race.date)
  #     data_array = []
  #     row.css('td').each_with_index do |field, index|
  #       property = RESULT_PROPERTIES[race_fields_array[index]]
  #       if property
  #         result.update_attributes(property => field.text)
  #       elsif race_fields_array[index] == "Sex/Age"
  #         result.update_attributes("sex" => field.text[0])
  #         result.update_attributes("age" => field.text[1..2].to_i)
  #       end
  #     end
  #
  #     # find or create team
  #     team = Team.where(name: result.team)
  #     if team.empty?
  #       Team.create(name: result.team)
  #     end
  #
  #     #create or find runner
  #     birth_year = race.date.year - result.age
  #     runners = Runner.where(first_name: result.first_name, last_name: result.last_name)
  #     if runners.empty?
  #       result_runner = Runner.create(
  #         first_name: result.first_name,
  #         last_name: result.last_name,
  #         birth_year: birth_year,
  #         team: result.team,
  #         sex: result.sex,
  #         full_name: "#{result.first_name} #{result.last_name}",
  #         city: result.city,
  #         state: result.state,
  #         country: result.country
  #       )
  #     else
  #       found = false
  #
  #       # commented out to assume runner with same name is the same runner
  #
  #       runners.each do |runner|
  #         if runner.birth_year.between? birth_year - 1, birth_year + 1
  #           result_runner = runner
  #           found = true
  #           break
  #         end
  #       end
  #
  #       if not found
  #         result_runner = Runner.create(
  #           first_name: result.first_name,
  #           last_name: result.last_name,
  #           birth_year: birth_year,
  #           team: result.team,
  #           sex: result.sex,
  #           full_name: "#{result.first_name} #{result.last_name}",
  #           city: result.city,
  #           state: result.state,
  #           country: result.country
  #         )
  #       end
  #     end
  #
  #     result_runner.save!
  #
  #     result.update_attributes("runner_id" => result_runner.id)
  #     result.update_attributes("race_id" => race.id)
  #     result.save!
  #     puts "------------------------------------#{result.overall_place}: #{result.first_name} #{result.last_name}------------------------------------"
  #   end
  # end

  def scrape_race_info(race_results_page, race)
    race_info = race_results_page.parser.xpath("//span[@class='text']")[0]
    race_info_clean = race_info.text.split(/\r/).reject(&:empty?).join(';')
    attributes = {}

    attributes["distance"] = /Distance:\D*(\d?\.?\d+\D*\d?\.*\d+).*?(?:;|$)/
    attributes["date_and_time"] = /Date\/Time:\W*(.*?)(?:;|$)/
    attributes["location"] = /Location:\W*(.+?)(?:;|$)/
    attributes["weather"]  = /Weather:\W*(.*?)(?:;|$)/
    attributes["temperature"] = /(\d{1,3})\s?(?:d|D|f|F)/
    attributes["humidity"] = /(\d\d)%/
    attributes["sponsor"] = /Sponsor:\W*(.*?)(?:;|$)/
    attributes.each do |attribute, regex|
      if race_info_clean.match regex
        if "distance" == attribute
          race.update_attributes(attribute => race_info_clean.match(regex).captures[0].to_f)
        elsif ["temperature", "humidity"].include? attribute
          race.update_attributes(attribute => race_info_clean.match(regex).captures[0].to_i)
        else
          race.update_attributes(attribute => race_info_clean.match(regex).captures[0])
        end
      end
    end
  end

  def format_date(date_str)
    date = Date.strptime(date_str, '%m/%d/%y')
  end
end
