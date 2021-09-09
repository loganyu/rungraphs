class StravaSegmentMailer < ApplicationMailer
  REPORT_EMAIL = "rungraphs-reports@googlegroups.com"
  GENDER_TO_TITLE = {
      "M" => "Men's Leaderboards",
      "F" => "Women's Leaderboards"
    }

  def strava_segment_report(gender, report_email = REPORT_EMAIL)

    strava_segment_data_provider = Rungraphs::Analytics::StravaSegmentDataProvider.new
    @leaderboards = {
      GENDER_TO_TITLE[gender] => strava_segment_data_provider.get_segment_leaderboard_data(gender)
    }

    mail(:to => report_email, :subject => "Rungraphs Strava Segment Weekly Report #{GENDER_TO_TITLE[gender]} #{Time.now.in_time_zone('Eastern Time (US & Canada)').to_date.strftime('%m/%d/%y')}")
  end
end
