module Rungraphs
  module Analytics
    class StravaSegmentDataProvider
      MAX_RETRIES = 3
      DATE_RANGE = "this_week"
      ENTRY_FIELD_KEY = "entries"
      METERS_TO_MILES = 0.000621371
      MINIMUM_MALE_PACE = 4*60
      MAXIMUM_MALE_PACE = 6*60
      MINIMUM_FEMALE_PACE = 4*60
      MAXIMUM_FEMALE_PACE = 7*60
      SEGMENTS = {
        'PP Hill to "Lane Use" Sign' => 9053875,
        "Lower Mile" => 7336914,
        "Center Drive 800 m" => 10537019,
        "Flushing Flats" => 1756331,
        "Flushing stretch" => 10703307,
        "West Lake Bomb" => 2627325,
        "McCarren Park Lap" => 3673193,
        "Pulaski Bridge" => 6401050,
        "The Brooklyn Mile" => 12472244,
        "Kent Ave 14th to Metropolitan" => 4857422,
        "Franklin - Huron to N 12th" => 8541301,
        "Williamsburg Bridge (Manhattan to Brooklyn)" => 6401036,
        "Williamsburg Bridge - Westbound" => 6254102,
        "Prospect Park Long Loop" => 3020587,
        "Manhattan Bridge to Manhattan" => 1424290,
        "Manhattan Bridge MH>BK" => 2622770,
        "Brooklyn Bridge (Brooklyn to Manhattan)" => 6400995,
        "Brooklyn Bridge (Manhattan to Brooklyn)" => 6400998,
        "Columbia: Degraw to Atlantic" => 5701493,
        "Red Hook 400m Loop" => 3669529
      }

      def initialize
        @client = Strava::Api::V3::Client.new(:access_token => Rails.application.secrets.strava_access_token)
      end

      def get_segment_leaderboard_data(gender)
        SEGMENTS.map do |segment_name, segment_id|
          segment = @client.retrieve_a_segment(segment_id)
          all_entries = @client.segment_leaderboards(segment_id, {:date_range => "this_week", :gender => gender, :context_entries => 0})["entries"]
          display_entries = []
          all_entries.each do |entry|
            pace = entry['moving_time']/(segment['distance']*METERS_TO_MILES)
            if gender == 'M'
              if pace < MINIMUM_MALE_PACE || pace > MAXIMUM_MALE_PACE
                next
              end
            end

            if gender == 'F'
              if pace < MINIMUM_FEMALE_PACE || pace > MAXIMUM_FEMALE_PACE
                next
              end
            end

            if entry['rank'] > 15
              next
            end

            entry['distance'] = segment['distance']

            display_entries << entry
          end

          if display_entries.empty?
            nil
          else
            {
              :name => segment_name,
              :segment_id => segment_id,
              :entries => display_entries
            }
          end
        end.compact
      end
    end
  end
end
