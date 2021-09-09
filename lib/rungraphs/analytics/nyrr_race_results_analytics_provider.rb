module Rungraphs
  module Analytics
    class NyrrRaceResultsAnalyticsProvider
      MIN_AG_PERCENTAGE = 70

      def initialize(race_slug)
        @race = Race.where(:slug => race_slug).first
      end

      def get_local_competitive_race_results
        lc_results = @race.results.where(:ag_percent => 70..100, :team => 0, :city => "brooklyn").order(:overall_place)
        if lc_results.length == 0
          return
        end
        race_info = {
          :name => @race.name,
          :race_slug => @race.slug,
          :date => @race.date,
          :date_and_time => @race.date_and_time,
          :location => @race.location,
          :weather => @race.weather
        }
        results = lc_results.map do |result|
          current_race_time = result.net_time || result.finish_time || result.gun_time
          if current_race_time[0] == "0"
            current_race_time = current_race_time[2..-1]
          end
          {
            :name => "#{result.first_name} #{result.last_name}",
            :gender => result.sex,
            :age => result.age,
            :ag_percent => result.ag_percent,
            :net_time => current_race_time,
            :pace => result.pace_per_mile,
            :runner_slug => Runner.find(result.runner_id).slug,
            :city => result.city,
            :state => result.state,
            :country => result.country
          }
        end
        race_data = {
          :race_info => race_info,
          :results => results
        }

        return race_data
      end

      def get_local_competitive_qualifiers(team_code)
        lc_results = @race.results.where(:ag_percent => 70..100, :team => team_code).order(:overall_place)
        if lc_results.length == 0
          return
        end
        race_info = {
          :name => @race.name,
          :race_slug => @race.slug,
          :date => @race.date,
          :date_and_time => @race.date_and_time,
          :location => @race.location,
          :weather => @race.weather,
          :team_code => team_code
        }

        lc_qualifiers = []
        lc_results.each do |result|
          current_race_time = result.net_time || result.finish_time || result.gun_time
          if current_race_time[0] == "0"
            current_race_time = current_race_time[2..-1]
          end
          runner = Runner.find(result.runner_id)

          qualifying_result = runner.results.where("ag_percent > 70 AND (distance != 1.0 AND distance != 0.2) AND date > ? AND date < ?", 1.year.ago, result.date).order('date DESC').first
          if !qualifying_result.nil?
            qualifying_race = Race.select(:slug, :name).find(qualifying_result.race_id)
            lc_qualifiers << {
              :name => runner.full_name,
              :runner_slug => runner.slug,
              :gender => runner.sex,
              :age => result.age,
              :pace => result.pace_per_mile,
              :net_time => current_race_time,
              :ag_percent => result.ag_percent,
              :first_result_net_time => qualifying_result.net_time,
              :first_race_slug => qualifying_race.slug,
              :first_race_name => qualifying_race.name,
              :first_result_date => qualifying_result.date,
              :first_result_ag_percent => qualifying_result.ag_percent,
              :first_result_pace => qualifying_result.pace_per_mile
            }
          end
        end


        race_data = {
          :race_info => race_info,
          :lc_qualifiers => lc_qualifiers
        }

        return race_data
      end

      def get_team_race_data(team_name, team_champs = false)
        if @race.nil?
          return
        end
        team_results = @race.results.where(:team => team_name).order(:overall_place)
        male_team_results = @race.results.where(:team => team_name, :sex => 'm').order(:overall_place)
        female_team_results = @race.results.where(:team => team_name, :sex => 'f').order(:overall_place)
        if male_team_results.length == 0 && female_team_results == 0
          return
        end
        race_info = {
          :name => @race.name,
          :race_slug => @race.slug,
          :date => @race.date,
          :distance => @race.distance,
          :date_and_time => @race.date_and_time,
          :location => @race.location,
          :weather => @race.weather,
          :code => @race.code
        }
        male_results = male_team_results.map do |result|
          current_race_time = result.net_time || result.finish_time || result.gun_time
          if current_race_time[0] == "0"
            current_race_time = current_race_time[2..-1]
          end
          {
            :name => "#{result.first_name} #{result.last_name}",
            :gender => result.sex,
            :age => result.age,
            :ag_percent => result.ag_percent,
            :net_time => current_race_time,
            :pace => result.pace_per_mile,
            :runner_slug => Runner.find(result.runner_id).slug,
            :city => result.city,
            :state => result.state,
            :country => result.country,
            :overall_place => result.overall_place,
            :gender_place => result.gender_place,
            :ag_gender_place => result.ag_gender_place,
            :age_place => result.age_place
          }
        end

        female_results = female_team_results.map do |result|
          current_race_time = result.net_time || result.finish_time || result.gun_time
          if current_race_time[0] == "0"
            current_race_time = current_race_time[2..-1]
          end
          {
            :name => "#{result.first_name} #{result.last_name}",
            :gender => result.sex,
            :age => result.age,
            :ag_percent => result.ag_percent,
            :net_time => current_race_time,
            :pace => result.pace_per_mile,
            :runner_slug => Runner.find(result.runner_id).slug,
            :city => result.city,
            :state => result.state,
            :country => result.country,
            :overall_place => result.overall_place,
            :gender_place => result.gender_place,
            :ag_gender_place => result.ag_gender_place,
            :age_place => result.age_place
          }
        end

        ag_award_results = []
        team_results.each do |result|
          current_race_time = result.net_time || result.finish_time || result.gun_time
          if current_race_time[0] == "0"
            current_race_time = current_race_time[2..-1]
          end
          if result.age_place <= 10
            ag_award_results << {
              :name => "#{result.first_name} #{result.last_name}",
              :time => current_race_time,
              :age_place => result.age_place,
              :age => result.age,
              :gender => result.sex
            }
          end
        end

        prs = []
        first_team_race = []
        first_race_in_distance = []
        team_results.each do |result|
          runner = Runner.find(result.runner_id)
          other_results_in_distance = runner.results.where(:distance => result.distance).where("date < ?", result.date)
          current_race_time = result.net_time || result.finish_time || result.gun_time
          if current_race_time[0] == "0"
            current_race_time = current_race_time[2..-1]
          end

          if !other_results_in_distance.empty? && other_results_in_distance.all? do |other_result|
              if other_result.net_time? && other_result.net_time >= result.net_time
                true
              elsif !other_result.net_time? && other_result.finish_time? && other_result.finish_time >= result.net_time
                true
              elsif !other_result.net_time? && !other_result.finish_time? && other_result.gun_time? && other_result.gun_time >= result.net_time
                true
              else
                false
              end
            end
            other_results_by_time = {}
            other_results_in_distance.each do |result|
              if result.net_time
                other_results_by_time[result.net_time] = result
              elsif result.finish_time
                other_results_by_time[result.finish_time] = result
              elsif result.gun_time
                other_results_by_time[result.gun_time] = result
              else
                next
              end
            end
            previous_best_result_array = other_results_by_time.sort.first
            previous_best_result = previous_best_result_array[1]
            previous_best_time = previous_best_result_array[0]
            if previous_best_time[0] == "0"
              previous_best_time = previous_best_time[2..-1]
            end
            previous_best_race = Race.select(:name, :date).find(previous_best_result.race_id)
            prs << {
              :name => "#{result.first_name} #{result.last_name}",
              :pr_time => current_race_time,
              :old_pr_race => previous_best_race.name,
              :old_pr_date => previous_best_race.date,
              :old_pr_time => previous_best_time
            }
          end

          other_results_with_team = runner.results.where(:team => team_name).where("date < ?", result.date)
          if other_results_with_team.empty?
            first_team_race << {
              :name => "#{result.first_name} #{result.last_name}"
            }
          end
          if other_results_in_distance.empty?
            first_race_in_distance <<  {
              :name => "#{result.first_name} #{result.last_name}"
            }
          end
        end
        team_results = {}
        team_result_types = {
          "Open Class Men" => @race.men_results,
          "Open Class Women" => @race.women_results,
          "Masters Men 40+" => @race.men_40_results,
          "Masters Women 40+" => @race.women_40_results,
          "Masters Men 50+" => @race.men_50_results,
          "Masters Women 50+" => @race.women_50_results,
          "Masters Men 60+" => @race.men_60_results,
          "Masters Women 60+" => @race.women_60_results,
          "Masters Men 60+" => @race.men_60_results,
          "Masters Women 60+" => @race.women_60_results,
          "Masters Men 70+" => @race.men_70_results,
          "Masters Women 70+" => @race.women_70_results,
        }

        team_result_types.each do |type, results|
          if results
            team_place = 1
            results.each do |result|
              if result["team"] == team_name
                if type == "Open Class Men" || type == "Open Class Women"
                  if team_champs
                    number_of_scoring_runners = 10
                  else
                    number_of_scoring_runners = 5
                  end
                else
                  if team_champs && (type == "Masters Men 40+" || type == "Masters Women 40+")
                    number_of_scoring_runners = 5
                  else
                    number_of_scoring_runners = 3
                  end
                end

                team_results[type] = {
                  :team_place => team_place,
                  :runners => result["runners"],
                  :total_time => result["total_time"],
                  :number_of_scoring_runners => number_of_scoring_runners
                }
              else
                team_place += 1
              end
            end
          end
        end

        race_data = {
          :race_info => race_info,
          :male_results => male_results,
          :female_results => female_results,
          :prs => prs,
          :first_team_race => first_team_race,
          :first_race_in_distance => first_race_in_distance,
          :ag_award_results => ag_award_results,
          :team_results => team_results
        }
        
        return race_data
      end
    end
  end
end