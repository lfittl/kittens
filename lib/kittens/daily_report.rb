module Kittens::DailyReport
  extend self

  def call
    notifier = Slack::Notifier.new ENV['SLACK_WEBHOOK']
    notifier.ping format('Last 24 hours: %d timeout errors, %d server errors. <%s|Details>.',
                         Kittens::Stats.timeouts.count, Kittens::Stats.server_errors.count,
                         ENV['APP_URL'])
  end
end
