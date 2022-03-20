class NyrrRaceResultsMailer < ApplicationMailer
  REPORT_EMAIL = "rungraphs-reports@googlegroups.com"

  def unattached_brooklyn_runners_report(race_slug, report_email = REPORT_EMAIL)
    nyrr_race_results_provider = Rungraphs::Analytics::NyrrRaceResultsAnalyticsProvider.new(race_slug)
    @race_data = nyrr_race_results_provider.get_local_competitive_race_results()
    if @race_data.nil?
      puts "No race found. Bailing on email."
      return
    else
      mail(:to => report_email, :subject => "NYRR Unattached Brooklyn Runners for #{@race_data[:race_info][:name]}")
    end
  end

  def local_competitive_qualifiers_report(team_code, race_slug, report_email = REPORT_EMAIL)
    nyrr_race_results_provider = Rungraphs::Analytics::NyrrRaceResultsAnalyticsProvider.new(race_slug)
    @race_data = nyrr_race_results_provider.get_local_competitive_qualifiers(team_code)
    if @race_data.nil?
      puts "No race found. Bailing on email."
      return
    else
      mail(:to => report_email, :subject => "NBR Local Competitive Qualifiers at #{@race_data[:race_info][:name]}")
    end
  end

  def team_results_report(team_code, race_slug, report_email = REPORT_EMAIL, team_champs = false)
    nyrr_race_results_provider = Rungraphs::Analytics::NyrrRaceResultsAnalyticsProvider.new(race_slug)
    @race_data = nyrr_race_results_provider.get_team_race_data(team_code, team_champs)
    @team_code = team_code
    if @race_data.nil?
      puts "No race found. Bailing on email."
      return
    elsif
      @race_data[:male_results].count == 0 && @race_data[:female_results].count == 0 && @race_data[:non_binary_results].count == 0
      puts "No runners on team. Bailing on email."
      return
    else
      mail(:to => report_email, :subject => "#{team_code.upcase} #{@race_data[:race_info][:name]} Race Results")
    end
  end
end
