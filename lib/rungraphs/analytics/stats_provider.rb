module Rungraphs
  module Analytics
    class StatsProvider
      def initialize(team)
        @team = team
      end

      def total_stats
        results = Result.joins(:runner, :race).where(:team => @team)
        return get_stats(results, false)
      end

      def yearly_stats(year)
        results_criteria = {
          :date => Date.new(year, 1, 1)..Date.new(year, 12, 31),
          :team => @team
        }
        results = Result.joins(:runner, :race).where(results_criteria)
        total_yearly_stats = get_stats(results)
        men_open_yearly_stats = get_stats(results.select{|r| r.sex == 'm'})
        women_open_yearly_stats = get_stats(results.select{|r| r.sex == 'f'})
        men_40_yearly_stats = get_stats(results.select{|r| r.sex == 'm' && r.age >= 40})
        women_40_yearly_stats = get_stats(results.select{|r| r.sex == 'f' && r.age >= 40})
        men_50_yearly_stats = get_stats(results.select{|r| r.sex == 'm' && r.age >= 50})
        women_50_yearly_stats = get_stats(results.select{|r| r.sex == 'f' && r.age >= 50})
        men_60_yearly_stats = get_stats(results.select{|r| r.sex == 'm' && r.age >= 60})
        women_60_yearly_stats = get_stats(results.select{|r| r.sex == 'f' && r.age >= 60})
        men_70_yearly_stats = get_stats(results.select{|r| r.sex == 'm' && r.age >= 70})
        women_70_yearly_stats = get_stats(results.select{|r| r.sex == 'f' && r.age >= 70})

        return {
          :total_yearly_stats => total_yearly_stats,
          :men_open_yearly_stats => men_open_yearly_stats,
          :women_open_yearly_stats => women_open_yearly_stats,
          :men_40_yearly_stats => men_40_yearly_stats,
          :women_40_yearly_stats => women_40_yearly_stats,
          :men_50_yearly_stats => men_50_yearly_stats,
          :women_50_yearly_stats => women_50_yearly_stats,
          :men_60_yearly_stats => men_60_yearly_stats,
          :women_60_yearly_stats => women_60_yearly_stats,
          :men_70_yearly_stats => men_70_yearly_stats,
          :women_70_yearly_stats => women_70_yearly_stats,
        }
      end

      private

        def get_stats(results, yearly = true)
          if results.empty?
            return {}
          end
          runners = results.map(&:runner).uniq

          # Total Team NYRR Race Finishes
          total_finishers = results.count
          # Total Team Number of Runners
          total_runners = runners.count

          # Total Team Miles Raced
          total_miles = results.map(&:distance).sum.round(1)

          # First time racers with team this year.
          if yearly == true
            year = results.first.date.year
            first_runners = runners.select do |runner|
              prev_year_results = runner.results
                .where(:team => @team)
                .where("date < ?", Date.new(year, 1 ,1))
              prev_year_results.count == 0
            end.count
          else
            first_runners = nil
          end

          # Most popular race distances
          races_by_distance = {}
          results.each do |result|
            races_by_distance[result.distance] ||= 0
            races_by_distance[result.distance] += 1
          end
          races_by_distance = races_by_distance.sort_by {|k,v| k}
          # Most races with team in 2018
          most_races_with_team ||= {}
          results.each do |result|
            most_races_with_team[result.full_name] ||= 0
            most_races_with_team[result.full_name] += 1
          end
          most_races_with_team = most_races_with_team.sort_by {|k,v| v}.reverse.take(40)

          # highest AG results
          highest_ag_by_distance = {}
          distances = results.map(&:distance).uniq.sort
          distances.each do |distance|
            highest_ag_by_distance[distance] = results.select{|result| result.distance == distance}
                   .sort_by{|r| r.ag_percent}.reverse
                   .take(20)
                   .map{|r| [r.full_name, r.age, r.net_time, r.ag_percent, r.date, r.race.name]}
          end

          return {
            :total_finishers => total_finishers,
            :total_runners => total_runners,
            :total_miles => total_miles,
            :first_runners => first_runners,
            :races_by_distance => races_by_distance,
            :most_races_with_team => most_races_with_team,
            :highest_ag_by_distance => highest_ag_by_distance,
          }
        end
    end
  end
end