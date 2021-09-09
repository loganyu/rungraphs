# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!

ActionMailer::Base.smtp_settings = {
  :address        => ENV["ACTION_MAILER_ADDRESS"],
  :domain         => ENV["ACTION_MAILER_DOMAIN"],
  :port           => ENV["ACTION_MAILER_PORT"],
  :user_name      => ENV["ACTION_MAILER_USER_NAME"],
  :password       => ENV["ACTION_MAILER_PASSWORD"],
  :authentication => :plain,
  :enable_starttls_auto => true
}
