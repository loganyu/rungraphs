class SearchController < ApplicationController
	def search_races
	    results = Race.search params[:q]
	    races = parse_race_results(results)

	    render partial: 'results/search_races', locals: { races: races }
	end

	def search_runners
	    results = Runner.search params[:q]
	    runners = parse_runner_results(results)
	    render partial: 'results/search_runners', locals: { runners: runners }
	end

	def search_all
		results = Race.search params[:q]
	    races = parse_race_results(results)

	    results = Runner.search params[:q]
	    runners = parse_runner_results(results)

	    all = races + runners
		all_results = all.sort_by {|hash| hash[:score] }.reverse

		render partial: 'results/search_all', locals: { results: all_results }
	end
end

private

def parse_race_results(results)
	races = []
    results.as_json.each do |result|
    	races << {name: result["fields"]["name"][0], date: result["fields"]["date"][0], id: result["fields"]["id"][0], score: result["_score"], type: "race", slug: result["fields"]["slug"] }
    end
    races
end

def parse_runner_results(results)
	runners = []
    results.as_json.each do |result|
    	runners << {full_name: result["fields"]["full_name"][0], team: result["fields"]["team"][0], id: result["fields"]["id"][0], score: result["_score"], type: "runner", slug: result["fields"]["slug"] }
    end
    runners
end
