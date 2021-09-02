Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'races#index'

  get :home, to: 'home#home', :path => ''

  resources :runners
  resources :races do
    member do
      get :get_race_results, to: "races#get_race_results", path: "api/race_results/:id"
    end
  end

  get :get_race_results, to: 'races#get_race_results', :path => "api/race_results/:id"
  get :get_teams, to: 'races#get_teams', :path => "api/get_teams/:id"

  resources :teams
  get :get_team_results, to: 'teams#get_team_results', :path => "api/team_results/:id"

  resources :projected_races, :path => 'predictions'

  get :get_projected_race_results, to: 'projected_races#get_projected_race_results', :path => "api/projected_race_results/:id"
  get :get_projected_teams, to: 'projected_races#get_projected_teams', :path => "api/get_projected_teams/:id"

  get :search_races, to: 'search#search_races'
  get :search_runners, to: 'search#search_runners'
  get :search_all, to: 'search#search_all'
end
