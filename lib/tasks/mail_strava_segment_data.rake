desc "Send strava segment weekly report"

namespace :strava do
  task :mail_segment_data => :environment do
    if Time.now.monday?
      StravaSegmentMailer.strava_segment_report("M").deliver_now
      StravaSegmentMailer.strava_segment_report("F").deliver_now
    else
      puts "bailing because it is not Monday"
    end
  end
end